module "vpc" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//vpc?ref=v1.0.0"

  name = "shared-app"
  cidr = var.cidr

  azs = var.azs

  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway = true
  single_nat_gateway = true
}

module "ecr" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//ecr?ref=v1.0.0"

  repository_name               = "eticket-app-repo"
  repository_type               = "private"
  repository_image_tag_mutability = "MUTABLE"
  repository_image_scan_on_push = true
  repository_force_delete       = true

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

  name = "shared-app-alb"

  load_balancer_type = "application"
  internal           = false

  subnets = module.vpc.public_subnets

  security_group_ingress_rules = {
    http = {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTP"
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      fixed_response = {
        content_type = "text/plain"
        message_body = "Not Found"
        status_code  = "404"
      }

      rules = {
        eticket = {
          priority = 10

          actions = [
            {
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
                  "/eticket/*"
                ]
              }
            }
          ]
        }

        sticky_notes = {
          priority = 20

          actions = [
            {
              forward = {
                target_group_key = "sticky-notes"
              }
            }
          ]

          conditions = [
            {
              path_pattern = {
                values = [
                  "/sticky",
                  "/sticky/*"
                ]
              }
            }
          ]
        }
      }
    }
  }

  target_groups = {
    eticket = {
      name        = "eticket-app-tg"
      port        = 3000
      protocol    = "HTTP"
      target_type = "ip"

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

    sticky-notes = {
      name        = "sticky-notes-tg"
      port        = 3000
      protocol    = "HTTP"
      target_type = "ip"

      health_check = {
        enabled             = true
        path                = "/"
        protocol            = "HTTP"
        matcher             = "200-399"
      }
    }
  }
}

module "ecs" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//ecs?ref=v1.0.0"

  cluster_name = "app-cluster"

  cluster_setting = [
    {
      name  = "containerInsights"
      value = "enabled"
    }
  ]

  vpc_id = module.vpc.vpc_id

  services = {
    app = {
      name          = "eticket-app-service"
      desired_count = 1

      launch_type = "FARGATE"

      subnet_ids = module.vpc.private_subnets

      create_security_group = true

      security_group_ingress_rules = {
        alb = {
          from_port = 3000
          to_port   = 3000
          protocol  = "tcp"

          security_group_id = module.alb.security_group_id
        }
      }

      security_group_egress_rules = {
        all = {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_ipv4   = "0.0.0.0/0"
        }
      }

      load_balancer = {
  app = {
    target_group_arn = module.alb.target_groups["eticket"].arn
    container_name   = "app"
    container_port   = 3000
  }
}

      task_definition = {
        cpu    = 256
        memory = 512

        network_mode = "awsvpc"

        requires_compatibilities = [
          "FARGATE"
        ]

        container_definitions = [
          {
            name  = "app"
            image = "${module.ecr.repository_url}:${var.image_tag}"

            essential = true

            port_mappings = [
              {
                containerPort = 3000
                hostPort      = 3000
                protocol      = "tcp"
              }
            ]

            enable_cloudwatch_logging = true

            create_cloudwatch_log_group = true

            cloudwatch_log_group_name = "/ecs/eticket-app"

            cloudwatch_log_group_retention_in_days = 7
          }
        ]
      }
    }
  }
}
module "sns" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//sns?ref=v1.0.0"

  name = "eticket-app-alerts"

  create_subscription = true

  subscriptions = {
    email = {
      protocol = "email"
      endpoint = var.alert_email
    }
    phone = {
      protocol = "sms"
      endpoint = var.alert_phone
    }
  }

  tags = {
    Application = "eticket-app"
    Environment = "production"
  }
}

module "cloudwatch" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//cloudwatch/modules/metric-alarm?ref=v1.0.0"

  alarm_name        = "eticket-app-cpu-high"
  alarm_description = "E-ticket ECS service CPU usage is high"

  comparison_operator = "GreaterThanOrEqualToThreshold"

  evaluation_periods = 2
  threshold          = 80
  period             = 60

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization"
  statistic   = "Average"
  unit        = "Percent"

  dimensions = {
    ClusterName = "app-cluster"
    ServiceName = "eticket-app-service"
  }

  alarm_actions = [
    module.sns.topic_arn
  ]

  ok_actions = [
    module.sns.topic_arn
  ]
}