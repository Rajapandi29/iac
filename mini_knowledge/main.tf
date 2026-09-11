module "vpc" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//vpc?ref=v1.0.0"

  name = var.app_name
  cidr = var.vpc_cidr

  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway = true
  single_nat_gateway  = true

  tags = {
    Project     = var.app_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


module "alb" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//alb?ref=v1.0.0"

  name = "${var.app_name}-alb"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  internal = false

  security_group_ingress_rules = {
    http = {
      description = "Allow HTTP"
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }


  target_groups = {
    streamlit = {
      name        = "${var.app_name}-streamlit-tg"
      port        = var.streamlit_port
      protocol    = "HTTP"
      target_type = "ip"

      # ECS Fargate automatically registers task IPs.
      # Do not create a static Terraform target attachment.
      create_attachment = false

      health_check = {
        enabled             = true
        path                = "/"
        protocol            = "HTTP"
        matcher             = "200-399"
        interval            = 30
        timeout             = 10
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }
    }

    fastapi = {
      name        = "${var.app_name}-fastapi-tg"
      port        = var.fastapi_port
      protocol    = "HTTP"
      target_type = "ip"

      # ECS Fargate automatically registers task IPs.
      # Do not create a static Terraform target attachment.
      create_attachment = false

      health_check = {
        enabled             = true
        path                = "/health"
        protocol            = "HTTP"
        matcher             = "200-399"
        interval            = 30
        timeout             = 10
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }
    }
  }


  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      # Default traffic goes to Streamlit.
      forward = {
        target_group_key = "streamlit"
      }

      # /backend and /backend/* go to FastAPI.
      rules = {
        fastapi = {
          priority = 10

          actions = [
            {
              forward = {
                target_group_key = "fastapi"
              }
            }
          ]

          conditions = [
            {
              path_pattern = {
                values = [
                  "/backend",
                  "/backend/*"
                ]
              }
            }
          ]
        }
      }
    }
  }

  tags = {
    Project     = var.app_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}



module "ecr_streamlit" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//ecr?ref=v1.0.0"

  create = true

  repository_name                 = "${var.app_name}-streamlit"
  repository_image_tag_mutability = "IMMUTABLE"
  repository_image_scan_on_push   = true

  create_lifecycle_policy = true

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep latest 10 tagged images"

        selection = {
          tagStatus   = "tagged"
          tagPatternList = ["*"]
          countType   = "imageCountMoreThan"
          countNumber = 10
        }

        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Project     = var.app_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


module "ecr_fastapi" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//ecr?ref=v1.0.0"

  create = true

  repository_name                 = "${var.app_name}-fastapi"
  repository_image_tag_mutability = "IMMUTABLE"
  repository_image_scan_on_push   = true

  create_lifecycle_policy = true

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep latest 10 tagged images"

        selection = {
          tagStatus   = "tagged"
          tagPatternList = ["*"]
          countType   = "imageCountMoreThan"
          countNumber = 10
        }

        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Project     = var.app_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


resource "aws_cloudwatch_log_group" "streamlit" {
  name              = "/ecs/${var.app_name}/streamlit"
  retention_in_days = 7

  tags = {
    Project     = var.app_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}



resource "aws_cloudwatch_log_group" "fastapi" {
  name              = "/ecs/${var.app_name}/fastapi"
  retention_in_days = 7

  tags = {
    Project     = var.app_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


module "ecs" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//ecs?ref=v1.0.0"

  cluster_name = "${var.app_name}-cluster"

  cluster_setting = [
    {
      name  = "containerInsights"
      value = "enabled"
    }
  ]

  task_exec_iam_role_name = "${var.app_name}-execution-role"

  services = {


    streamlit = {
      name = "${var.app_name}-streamlit"

      cpu    = 256
      memory = 512

      desired_count = 1

      launch_type      = "FARGATE"
      assign_public_ip = false

      subnet_ids = module.vpc.private_subnets
      vpc_id     = module.vpc.vpc_id

      security_group_name = "${var.app_name}-streamlit-sg"

      health_check_grace_period_seconds = 60

      security_group_ingress_rules = {
        streamlit = {
          description                  = "ALB to Streamlit"
          from_port                    = var.streamlit_port
          to_port                      = var.streamlit_port
          ip_protocol                  = "tcp"
          referenced_security_group_id = module.alb.security_group_id
        }
      }

      security_group_egress_rules = {
        all = {
          ip_protocol = "-1"
          cidr_ipv4   = "0.0.0.0/0"
        }
      }

      deployment_circuit_breaker = {
        enable   = true
        rollback = true
      }

      network_mode             = "awsvpc"
      requires_compatibilities = ["FARGATE"]

      container_definitions = {
        streamlit = {
          name      = "streamlit"
          essential = true

          image = "${module.ecr_streamlit.repository_url}:${var.streamlit_image_tag}"

          cpu    = 256
          memory = 512

          readonlyRootFilesystem = false

          portMappings = [
            {
              name          = "streamlit"
              containerPort = var.streamlit_port
              hostPort      = var.streamlit_port
              protocol      = "tcp"
            }
          ]

          command = [
            "streamlit",
            "run",
            "frontend/streamlit_app.py",
            "--server.address=0.0.0.0",
            "--server.port=8501"
          ]

          environment = [
            {
              name  = "BACKEND_URL"
              value = "/backend"
            }
          ]

          enable_cloudwatch_logging              = true
          create_cloudwatch_log_group            = false
          cloudwatch_log_group_name              = "/ecs/${var.app_name}/streamlit"
          cloudwatch_log_group_retention_in_days = 7
        }
      }

      load_balancer = {
        streamlit = {
          target_group_arn = module.alb.target_groups["streamlit"].arn
          container_name   = "streamlit"
          container_port   = var.streamlit_port
        }
      }
    }


    fastapi = {
      name = "${var.app_name}-fastapi"

      # Previous FastAPI task was killed with:
      # Exit code 137 / OutOfMemoryError.
      cpu    = 2048
      memory = 4096

      desired_count = 1

      launch_type      = "FARGATE"
      assign_public_ip = false

      subnet_ids = module.vpc.private_subnets
      vpc_id     = module.vpc.vpc_id

      security_group_name = "${var.app_name}-fastapi-sg"

      health_check_grace_period_seconds = 60

      security_group_ingress_rules = {
        fastapi = {
          description                  = "ALB to FastAPI"
          from_port                    = var.fastapi_port
          to_port                      = var.fastapi_port
          ip_protocol                  = "tcp"
          referenced_security_group_id = module.alb.security_group_id
        }
      }

      security_group_egress_rules = {
        all = {
          ip_protocol = "-1"
          cidr_ipv4   = "0.0.0.0/0"
        }
      }

      deployment_circuit_breaker = {
        enable   = true
        rollback = true
      }

      network_mode             = "awsvpc"
      requires_compatibilities = ["FARGATE"]

      container_definitions = {
        fastapi = {
          name      = "fastapi"
          essential = true

          image = "${module.ecr_fastapi.repository_url}:${var.fastapi_image_tag}"

          cpu    = 2048
          memory = 4096

          readonlyRootFilesystem = false

          portMappings = [
            {
              name          = "fastapi"
              containerPort = var.fastapi_port
              hostPort      = var.fastapi_port
              protocol      = "tcp"
            }
          ]

          command = [
            "uvicorn",
            "main:app",
            "--host",
            "0.0.0.0",
            "--port",
            "8000"
          ]

          environment = [
            {
              name  = "DATABASE_URL"
              value = nonsensitive(var.neon_database_url)
            },
            {
              name  = "POSTGRES_DB"
              value = nonsensitive(var.neon_database_name)
            },
            {
              name  = "POSTGRES_USER"
              value = nonsensitive(var.neon_database_user)
            },
            {
              name  = "POSTGRES_PASSWORD"
              value = nonsensitive(var.neon_database_password)
            },
            {
              name  = "PORT"
              value = "8000"
            }
          ]

          healthCheck = {
            command = [
              "CMD-SHELL",
              "curl -f http://localhost:8000/health || exit 1"
            ]

            interval    = 30
            timeout     = 5
            retries     = 3
            startPeriod = 30
          }

          enable_cloudwatch_logging              = true
          create_cloudwatch_log_group            = false
          cloudwatch_log_group_name              = "/ecs/${var.app_name}/fastapi"
          cloudwatch_log_group_retention_in_days = 7
        }
      }

      load_balancer = {
        fastapi = {
          target_group_arn = module.alb.target_groups["fastapi"].arn
          container_name   = "fastapi"
          container_port   = var.fastapi_port
        }
      }
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.streamlit,
    aws_cloudwatch_log_group.fastapi
  ]
}

module "sns" {
  source = "git::https://github.com/Rajapandi29/terraform-modules.git//sns?ref=v1.0.0"

  name = "${var.app_name}-alerts"

  subscriptions = var.alert_email != "" ? {
    email = {
      protocol = "email"
      endpoint = var.alert_email
    }
  } : {}

  tags = {
    Project     = var.app_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


resource "aws_cloudwatch_metric_alarm" "streamlit_unhealthy" {
  alarm_name        = "${var.app_name}-streamlit-unhealthy"
  alarm_description = "Streamlit ALB target is unhealthy"

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"

  statistic          = "Maximum"
  period             = 60
  evaluation_periods = 2

  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    LoadBalancer = module.alb.arn_suffix
    TargetGroup  = module.alb.target_groups["streamlit"].arn_suffix
  }

  alarm_actions = [
    module.sns.topic_arn
  ]

  treat_missing_data = "breaching"
}



resource "aws_cloudwatch_metric_alarm" "fastapi_unhealthy" {
  alarm_name        = "${var.app_name}-fastapi-unhealthy"
  alarm_description = "FastAPI ALB target is unhealthy"

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"

  statistic          = "Maximum"
  period             = 60
  evaluation_periods = 2

  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    LoadBalancer = module.alb.arn_suffix
    TargetGroup  = module.alb.target_groups["fastapi"].arn_suffix
  }

  alarm_actions = [
    module.sns.topic_arn
  ]

  treat_missing_data = "breaching"
}



resource "aws_cloudwatch_metric_alarm" "streamlit_running_tasks" {
  alarm_name        = "${var.app_name}-streamlit-no-running-tasks"
  alarm_description = "Streamlit ECS service has no running tasks"

  namespace   = "ECS/ContainerInsights"
  metric_name = "RunningTaskCount"

  statistic          = "Minimum"
  period             = 60
  evaluation_periods = 2

  threshold           = 1
  comparison_operator = "LessThanThreshold"

  dimensions = {
    ClusterName = "${var.app_name}-cluster"
    ServiceName = "${var.app_name}-streamlit"
  }

  alarm_actions = [
    module.sns.topic_arn
  ]

  treat_missing_data = "breaching"
}


resource "aws_cloudwatch_metric_alarm" "fastapi_running_tasks" {
  alarm_name        = "${var.app_name}-fastapi-no-running-tasks"
  alarm_description = "FastAPI ECS service has no running tasks"

  namespace   = "ECS/ContainerInsights"
  metric_name = "RunningTaskCount"

  statistic          = "Minimum"
  period             = 60
  evaluation_periods = 2

  threshold           = 1
  comparison_operator = "LessThanThreshold"

  dimensions = {
    ClusterName = "${var.app_name}-cluster"
    ServiceName = "${var.app_name}-fastapi"
  }

  alarm_actions = [
    module.sns.topic_arn
  ]

  treat_missing_data = "breaching"
}