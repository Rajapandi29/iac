module "vpc" {
source = "git::https://github.com/Rajapandi29/terraform-modules.git//vpc?ref=v1.0.0"

name = var.app_name
cidr = var.vpc_cidr

azs             = var.azs
public_subnets  = var.public_subnets
private_subnets = var.private_subnets

enable_nat_gateway = true
single_nat_gateway = true

tags = {
Project     = var.app_name
Environment = var.environment
ManagedBy   = "Terraform"
}
}

module "alb" {
source = "git::https://github.com/Rajapandi29/terraform-modules.git//alb?ref=v1.0.0"

name               = "${var.app_name}-alb"
load_balancer_type = "application"

vpc_id  = module.vpc.vpc_id
subnets = module.vpc.public_subnets

security_group_ingress_rules = {
http = {
from_port   = 80
to_port     = 80
ip_protocol = "tcp"
description = "HTTP from Internet"
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
name        = "${var.app_name}-streamlit"
protocol    = "HTTP"
port        = var.streamlit_port
target_type = "ip"

```
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
  name        = "${var.app_name}-fastapi"
  protocol    = "HTTP"
  port        = var.fastapi_port
  target_type = "ip"

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
```

}

listeners = {
http = {
port     = 80
protocol = "HTTP"

```
  forward = {
    target_group_key = "streamlit"
  }

  rules = {
    backend = {
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
```

}

tags = {
Project     = var.app_name
Environment = var.environment
ManagedBy   = "Terraform"
}
}

module "ecr_streamlit" {
source = "git::https://github.com/Rajapandi29/terraform-modules.git//ecr?ref=v1.0.0"

repository_name = "${var.app_name}-streamlit"

repository_image_scan_on_push   = true
repository_image_tag_mutability = "IMMUTABLE"

repository_lifecycle_policy = jsonencode({
rules = [
{
rulePriority = 1
description  = "Keep last 10 tagged images"

```
    selection = {
      tagStatus      = "tagged"
      tagPatternList = ["*"]
      countType      = "imageCountMoreThan"
      countNumber    = 10
    }

    action = {
      type = "expire"
    }
  }
]
```

})

tags = {
Project     = var.app_name
Service     = "streamlit"
Environment = var.environment
}
}

module "ecr_fastapi" {
source = "git::https://github.com/Rajapandi29/terraform-modules.git//ecr?ref=v1.0.0"

repository_name = "${var.app_name}-fastapi"

repository_image_scan_on_push   = true
repository_image_tag_mutability = "IMMUTABLE"

repository_lifecycle_policy = jsonencode({
rules = [
{
rulePriority = 1
description  = "Keep last 10 tagged images"

```
    selection = {
      tagStatus      = "tagged"
      tagPatternList = ["*"]
      countType      = "imageCountMoreThan"
      countNumber    = 10
    }

    action = {
      type = "expire"
    }
  }
]
```

})

tags = {
Project     = var.app_name
Service     = "fastapi"
Environment = var.environment
}
}

resource "aws_cloudwatch_log_group" "streamlit" {
name              = "/ecs/${var.app_name}/streamlit"
retention_in_days = 7

tags = {
Project     = var.app_name
Environment = var.environment
Service      = "streamlit"
ManagedBy    = "Terraform"
}
}

resource "aws_cloudwatch_log_group" "fastapi" {
name              = "/ecs/${var.app_name}/fastapi"
retention_in_days = 7

tags = {
Project     = var.app_name
Environment = var.environment
Service      = "fastapi"
ManagedBy    = "Terraform"
}
}

module "ecs" {
source = "git::https://github.com/Rajapandi29/terraform-modules.git//ecs?ref=v1.0.0"

cluster_name = "${var.app_name}-cluster"

cluster_capacity_providers = [
"FARGATE"
]

default_capacity_provider_strategy = {
FARGATE = {
weight = 100
}
}

cluster_setting = [
{
name  = "containerInsights"
value = "enabled"
}
]

create_task_exec_iam_role = true

task_exec_iam_role_name = "${var.app_name}-execution-role"

depends_on = [
aws_cloudwatch_log_group.streamlit,
aws_cloudwatch_log_group.fastapi
]

services = nonsensitive({
streamlit = {
name = "${var.app_name}-streamlit"

```
  cpu    = 256
  memory = 512

  desired_count = 1

  launch_type = "FARGATE"

  assign_public_ip = false

  subnet_ids = module.vpc.private_subnets

  vpc_id = module.vpc.vpc_id

  security_group_name = "${var.app_name}-streamlit-sg"

  health_check_grace_period_seconds = 60

  security_group_ingress_rules = {
    streamlit = {
      description                   = "ALB to Streamlit"
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

  network_mode = "awsvpc"

  requires_compatibilities = [
    "FARGATE"
  ]

  container_definitions = {
    streamlit = {
      name = "streamlit"

      image = "${module.ecr_streamlit.repository_url}:${var.streamlit_image_tag}"

      essential = true

      cpu    = 256
      memory = 512

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

  cpu    = 512
  memory = 1024

  desired_count = 1

  launch_type = "FARGATE"

  assign_public_ip = false

  subnet_ids = module.vpc.private_subnets

  vpc_id = module.vpc.vpc_id

  security_group_name = "${var.app_name}-fastapi-sg"

  health_check_grace_period_seconds = 60

  security_group_ingress_rules = {
    fastapi = {
      description                   = "ALB to FastAPI"
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

  network_mode = "awsvpc"

  requires_compatibilities = [
    "FARGATE"
  ]

  container_definitions = {
    fastapi = {
      name = "fastapi"

      image = "${module.ecr_fastapi.repository_url}:${var.fastapi_image_tag}"

      essential = true

      cpu    = 512
      memory = 1024

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
```

})

tags = {
Project     = var.app_name
Environment = var.environment
ManagedBy   = "Terraform"
}
}

module "sns" {
source = "git::https://github.com/Rajapandi29/terraform-modules.git//sns?ref=v1.0.0"

name = "${var.app_name}-alerts"

subscriptions = {
email = {
protocol = "email"
endpoint = var.alert_email
}

```
sms = {
  protocol = "sms"
  endpoint = var.alert_phone
}
```

}
}

resource "aws_cloudwatch_metric_alarm" "streamlit_unhealthy" {
alarm_name          = "${var.app_name}-streamlit-unhealthy"
alarm_description   = "Streamlit target is unhealthy"
comparison_operator = "GreaterThanThreshold"
evaluation_periods  = 2
period              = 60
namespace           = "AWS/ApplicationELB"
metric_name         = "UnHealthyHostCount"
statistic           = "Maximum"
threshold           = 0

dimensions = {
TargetGroup  = module.alb.target_groups["streamlit"].arn_suffix
LoadBalancer = module.alb.arn_suffix
}

alarm_actions = [
module.sns.topic_arn
]

ok_actions = [
module.sns.topic_arn
]
}

resource "aws_cloudwatch_metric_alarm" "fastapi_unhealthy" {
alarm_name          = "${var.app_name}-fastapi-unhealthy"
alarm_description   = "FastAPI target is unhealthy"
comparison_operator = "GreaterThanThreshold"
evaluation_periods  = 2
period              = 60
namespace           = "AWS/ApplicationELB"
metric_name         = "UnHealthyHostCount"
statistic           = "Maximum"
threshold           = 0

dimensions = {
TargetGroup  = module.alb.target_groups["fastapi"].arn_suffix
LoadBalancer = module.alb.arn_suffix
}

alarm_actions = [
module.sns.topic_arn
]

ok_actions = [
module.sns.topic_arn
]
}

resource "aws_cloudwatch_metric_alarm" "streamlit_running_tasks" {
alarm_name          = "${var.app_name}-streamlit-no-tasks"
alarm_description   = "Streamlit ECS service has no running tasks"
comparison_operator = "LessThanThreshold"
evaluation_periods  = 2
period              = 60
namespace           = "ECS/ContainerInsights"
metric_name         = "RunningTaskCount"
statistic           = "Minimum"
threshold           = 1

dimensions = {
ClusterName = module.ecs.cluster_name
ServiceName = module.ecs.services["streamlit"].name
}

alarm_actions = [
module.sns.topic_arn
]

ok_actions = [
module.sns.topic_arn
]
}

resource "aws_cloudwatch_metric_alarm" "fastapi_running_tasks" {
alarm_name          = "${var.app_name}-fastapi-no-tasks"
alarm_description   = "FastAPI ECS service has no running tasks"
comparison_operator = "LessThanThreshold"
evaluation_periods  = 2
period              = 60
namespace           = "ECS/ContainerInsights"
metric_name         = "RunningTaskCount"
statistic           = "Minimum"
threshold           = 1

dimensions = {
ClusterName = module.ecs.cluster_name
ServiceName = module.ecs.services["fastapi"].name
}

alarm_actions = [
module.sns.topic_arn
]

ok_actions = [
module.sns.topic_arn
]
}
