module "vpc" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//vpc?ref=v1.0.0"

  name = var.name
  cidr = var.cidr

  azs = var.azs

  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway = true
  single_nat_gateway = true
}


module "eticket_ecr" {
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

        description = "Keep last 10 images"

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


module "stickynotes_ecr" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//ecr?ref=v1.0.0"

  repository_name = "stickynotes-app-repo"

  repository_type                 = "private"
  repository_image_tag_mutability = "MUTABLE"
  repository_image_scan_on_push   = true
  repository_force_delete         = true

  create_lifecycle_policy = true

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1

        description = "Keep last 10 images"

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

  name = "terraform-alb"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  load_balancer_type = "application"

  internal = false

  create_security_group = true

  security_group_ingress_rules = {
    http = {
      description = "Allow HTTP traffic from internet"

      cidr_ipv4 = "0.0.0.0/0"

      from_port   = 80
      to_port     = 80
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
        target_group_key = "stickynotes"
      }

      rules = {

        eticket = {

          priority = 10

          actions = [
            {
              order = 1

              forward = {
                target_group_key = "eticket"
              }
            }
          ]

          conditions = [
            {
              path_pattern = {
                values = [
                  "/eticket",
                  "/eticket/*",
                  "/eticket-app",
                  "/eticket-app/*"
                ]
              }
            }
          ]

          transform = {
            url_rewrite = {
              type = "url-rewrite"

              url_rewrite_config = {
                rewrite = {
                  regex   = "^/(eticket|eticket-app)(?:/(.*))?$"
                  replace = "/$2"
                }
              }
            }
          }
        }
      }
    }
  }

  target_groups = {

    eticket = {

      name = "${var.name}-eticket-tg"

      target_type = "ip"

      port     = var.eticket_container_port
      protocol = "HTTP"

      vpc_id = module.vpc.vpc_id

      create_attachment = false

      health_check = {
        enabled           = true
        path              = var.eticket_health_check_path
        protocol          = "HTTP"
        matcher           = "200-399"
        interval          = 30
        timeout           = 5
        healthy_threshold = 2
        unhealthy_threshold = 3
      }
    }

    stickynotes = {

      name = "${var.name}-stickynotes-tg"

      target_type = "ip"

      port     = var.stickynotes_container_port
      protocol = "HTTP"

      vpc_id = module.vpc.vpc_id

      create_attachment = false

      health_check = {
        enabled           = true
        path              = var.stickynotes_health_check_path
        protocol          = "HTTP"
        matcher            = "200-399"
        interval           = 30
        timeout            = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }
    }
  }
}


data "aws_lb" "terraform_alb" {
  name = "terraform-alb"

  depends_on = [module.alb]
}


module "ecs" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//ecs?ref=v1.0.0"

  cluster_name = "app-cluster"

  services = {

    eticket = {

      create         = true
      create_service = true

      name          = "eticket-app-service"
      desired_count = var.eticket_desired_count

      launch_type      = "FARGATE"
      assign_public_ip = false

      subnet_ids = module.vpc.private_subnets

      create_security_group = true

      vpc_id = module.vpc.vpc_id

      security_group_ingress_rules = {

        alb = {
          description = "Allow ALB traffic"

          referenced_security_group_id = module.alb.security_group_id

          from_port = tostring(var.eticket_container_port)
          to_port   = tostring(var.eticket_container_port)

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

      load_balancer = {

        eticket = {

          container_name = "eticket"

          container_port = var.eticket_container_port

          target_group_arn = module.alb.target_groups["eticket"].arn
        }
      }

      create_task_definition = true

      container_definitions = {

        eticket = {

          name = "eticket"

          image = "${module.eticket_ecr.repository_url}:${var.eticket_image_tag}"

          essential = true

          cpu    = var.eticket_cpu
          memory = var.eticket_memory

          portMappings = [
            {
              containerPort = var.eticket_container_port

              hostPort = var.eticket_container_port

              protocol = "tcp"
            }
          ]

          enable_cloudwatch_logging   = true
          create_cloudwatch_log_group = true

          cloudwatch_log_group_name = "/ecs/${var.name}/eticket"

          cloudwatch_log_group_retention_in_days = 7
        }
      }

      cpu    = var.eticket_cpu
      memory = var.eticket_memory

      network_mode = "awsvpc"

      requires_compatibilities = [
        "FARGATE"
      ]

      create_task_exec_iam_role = true

      create_tasks_iam_role = true
    }


    stickynotes = {

      create         = true
      create_service = true

      name          = "stickynotes-app-service"
      desired_count = var.stickynotes_desired_count

      launch_type      = "FARGATE"
      assign_public_ip = false

      subnet_ids = module.vpc.private_subnets

      create_security_group = true

      vpc_id = module.vpc.vpc_id

      security_group_ingress_rules = {

        alb = {
          description = "Allow ALB traffic"

          referenced_security_group_id = module.alb.security_group_id

          from_port = tostring(var.stickynotes_container_port)
          to_port   = tostring(var.stickynotes_container_port)

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

      load_balancer = {

        stickynotes = {

          container_name = "stickynotes"

          container_port = var.stickynotes_container_port

          target_group_arn = module.alb.target_groups["stickynotes"].arn
        }
      }

      create_task_definition = true

      container_definitions = {

        stickynotes = {

          name = "stickynotes"

          image = "${module.stickynotes_ecr.repository_url}:${var.stickynotes_image_tag}"

          essential = true

          cpu    = var.stickynotes_cpu
          memory = var.stickynotes_memory

          portMappings = [
            {
              containerPort = var.stickynotes_container_port

              hostPort = var.stickynotes_container_port

              protocol = "tcp"
            }
          ]

          enable_cloudwatch_logging   = true
          create_cloudwatch_log_group = true

          cloudwatch_log_group_name = "/ecs/${var.name}/stickynotes"

          cloudwatch_log_group_retention_in_days = 7
        }
      }

      cpu    = var.stickynotes_cpu
      memory = var.stickynotes_memory

      network_mode = "awsvpc"

      requires_compatibilities = [
        "FARGATE"
      ]

      create_task_exec_iam_role = true

      create_tasks_iam_role = true
    }
  }
}



module "sns" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//sns?ref=v1.0.0"

  name = "${var.name}-alerts"

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


resource "aws_cloudwatch_metric_alarm" "eticket_unhealthy" {

  alarm_name = "${var.name}-eticket-unhealthy"

  alarm_description = "E-ticket application target is unhealthy"

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"

  statistic = "Maximum"

  period             = 60
  evaluation_periods = 2

  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    TargetGroup  = module.alb.target_groups["eticket"].arn_suffix
    LoadBalancer = data.aws_lb.terraform_alb.arn_suffix
  }

  alarm_actions = [
    module.sns.topic_arn
  ]
}



resource "aws_cloudwatch_metric_alarm" "stickynotes_unhealthy" {

  alarm_name = "${var.name}-stickynotes-unhealthy"

  alarm_description = "StickyNotes application target is unhealthy"

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"

  statistic = "Maximum"

  period             = 60
  evaluation_periods = 2

  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    TargetGroup  = module.alb.target_groups["stickynotes"].arn_suffix
    LoadBalancer = data.aws_lb.terraform_alb.arn_suffix
  }

  alarm_actions = [
    module.sns.topic_arn
  ]
}