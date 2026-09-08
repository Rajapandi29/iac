module "vpc" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//vpc?ref=v1.0.0"

  name = "eticket-app"
  cidr = var.cidr
  azs  = var.azs

  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway = true
  single_nat_gateway = true
}



module "ecr" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//ecr?ref=v1.0.0"

  repository_name = "eticket-app-repo"

  repository_type                 = "private"
  repository_image_tag_mutability = "MUTABLE"
  repository_image_scan_on_push   = true
  repository_force_delete         = true

  create_lifecycle_policy = true

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"

        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}



module "sticky_ecr" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//ecr?ref=v1.0.0"

  repository_name = "sticky-notes-repo"

  repository_type                 = "private"
  repository_image_tag_mutability = "MUTABLE"
  repository_image_scan_on_push   = true
  repository_force_delete         = true

  create_lifecycle_policy = true

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"

        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}


module "alb" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//alb?ref=v1.0.0"

  name = "eticket-app-alb"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  load_balancer_type = "application"
  internal           = false

  create_security_group = true

  security_group_ingress_rules = {
    http = {
      description = "Allow HTTP traffic for eTicket"
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = "80"
      to_port     = "80"
      ip_protocol = "tcp"
    }

    sticky = {
      description = "Allow HTTP traffic for Sticky Notes"
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = "8080"
      to_port     = "8080"
      ip_protocol = "tcp"
    }
  }

  security_group_egress_rules = {
    all = {
      description = "Allow all outbound traffic"
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "-1"
    }
  }

  listeners = {

    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "app"
      }
    }

    sticky = {
      port     = 8080
      protocol = "HTTP"

      forward = {
        target_group_key = "sticky"
      }
    }
  }

  target_groups = {

    app = {
      name              = "eticket-app-tg"
      target_type       = "ip"
      port              = 3000
      protocol          = "HTTP"
      vpc_id            = module.vpc.vpc_id
      create_attachment = false

      health_check = {
        enabled             = true
        path                = "/"
        protocol            = "HTTP"
        matcher             = "200-399"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }
    }

    sticky = {
      name              = "sticky-notes-tg"
      target_type       = "ip"
      port              = var.container_port
      protocol          = "HTTP"
      vpc_id            = module.vpc.vpc_id
      create_attachment = false

      health_check = {
        enabled             = true
        path                = "/"
        protocol            = "HTTP"
        matcher             = "200-399"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }
    }
  }
}


module "ecs" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//ecs?ref=v1.0.0"

  cluster_name = "app-cluster"

  services = {


    app = {
      create         = true
      create_service = true

      name          = "eticket-app-service"
      desired_count = 1

      launch_type      = "FARGATE"
      assign_public_ip = false
      subnet_ids       = module.vpc.private_subnets

      create_security_group = true
      vpc_id                = module.vpc.vpc_id

      security_group_ingress_rules = {
        alb = {
          description                  = "Allow traffic from ALB"
          referenced_security_group_id = module.alb.security_group_id
          from_port                    = "3000"
          to_port                      = "3000"
          ip_protocol                  = "tcp"
        }
      }

      security_group_egress_rules = {
        all = {
          description = "Allow all outbound traffic"
          cidr_ipv4   = "0.0.0.0/0"
          ip_protocol = "-1"
        }
      }

      load_balancer = {
        app = {
          container_name   = "app"
          container_port   = 3000
          target_group_arn = module.alb.target_groups["app"].arn
        }
      }

      create_task_definition = true

      container_definitions = {
        app = {
          name      = "app"
          image     = "${module.ecr.repository_url}:${var.eticket_image_tag}"
          essential = true

          cpu    = 256
          memory = 512

          portMappings = [
            {
              containerPort = 3000
              hostPort      = 3000
              protocol      = "tcp"
            }
          ]

          enable_cloudwatch_logging   = true
          create_cloudwatch_log_group = true

          cloudwatch_log_group_name              = "/ecs/eticket-app"
          cloudwatch_log_group_retention_in_days = 7
        }
      }

      cpu    = 256
      memory = 512

      network_mode             = "awsvpc"
      requires_compatibilities = ["FARGATE"]

      create_task_exec_iam_role = true
      create_tasks_iam_role     = true
    }


    sticky = {
      create         = true
      create_service = true

      name          = "sticky-notes-service"
      desired_count = var.desired_count

      launch_type      = "FARGATE"
      assign_public_ip = false
      subnet_ids       = module.vpc.private_subnets

      create_security_group = true
      vpc_id                = module.vpc.vpc_id

      security_group_ingress_rules = {
        alb = {
          description                  = "Allow traffic from existing ALB"
          referenced_security_group_id = module.alb.security_group_id
          from_port                    = tostring(var.container_port)
          to_port                      = tostring(var.container_port)
          ip_protocol                  = "tcp"
        }
      }

      security_group_egress_rules = {
        all = {
          description = "Allow all outbound traffic"
          cidr_ipv4   = "0.0.0.0/0"
          ip_protocol = "-1"
        }
      }

      load_balancer = {
        sticky = {
          container_name   = "app"
          container_port   = var.container_port
          target_group_arn = module.alb.target_groups["sticky"].arn
        }
      }

      create_task_definition = true

      container_definitions = {
        app = {
          name      = "app"
          image     = "${module.sticky_ecr.repository_url}:${var.image_tag}"
          essential = true

          cpu    = var.cpu
          memory = var.memory

          portMappings = [
            {
              containerPort = var.container_port
              hostPort      = var.container_port
              protocol      = "tcp"
            }
          ]

          enable_cloudwatch_logging   = true
          create_cloudwatch_log_group = true

          cloudwatch_log_group_name              = "/ecs/sticky-notes"
          cloudwatch_log_group_retention_in_days = 7
        }
      }

      cpu    = var.cpu
      memory = var.memory

      network_mode             = "awsvpc"
      requires_compatibilities = ["FARGATE"]

      create_task_exec_iam_role = true
      create_tasks_iam_role     = true
    }
  }
}

module "sns" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//sns?ref=v1.0.0"

  name = "eticket-app-alerts"

  subscriptions = {
    email = {
      protocol = "email"
      endpoint = var.alert_email
    }

    sms = {
      protocol = "sms"
      endpoint = var.alert_phone
    }
  }
}