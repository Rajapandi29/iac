output "vpc_id" {
  description = "VPC ID"

  value = module.vpc.vpc_id
}


output "alb_dns_name" {
  description = "ALB DNS name"

  value = module.alb.dns_name
}

output "application_urls" {
  description = "Application URLs"

  value = {
    stickynotes = "http://${module.alb.dns_name}/"
    eticket     = "http://${module.alb.dns_name}/eticket-app"
  }
}


output "eticket_ecr_repository_url" {
  description = "Eticket ECR repository"

  value = module.eticket_ecr.repository_url
}

output "stickynotes_ecr_repository_url" {
  description = "Sticky Notes ECR repository"

  value = module.stickynotes_ecr.repository_url
}



output "ecs_cluster_name" {
  description = "ECS cluster name"

  value = "${var.name}-cluster"
}



output "eticket_target_group_arn" {
  description = "Eticket target group ARN"

  value = module.alb.target_groups["eticket"].arn
}

output "stickynotes_target_group_arn" {
  description = "Sticky Notes target group ARN"

  value = module.alb.target_groups["stickynotes"].arn
}