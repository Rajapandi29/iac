
output "name" {
  description = "Application name"
  value       = var.name
}


output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}


output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}


output "ecr_repository_name" {
  description = "eTicket ECR repository name"
  value       = module.ecr.repository_name
}

output "ecr_repository_url" {
  description = "eTicket ECR repository URL"
  value       = module.ecr.repository_url
}


output "sticky_ecr_repository_name" {
  description = "Sticky Notes ECR repository name"
  value       = module.sticky_ecr.repository_name
}

output "sticky_ecr_repository_url" {
  description = "Sticky Notes ECR repository URL"
  value       = module.sticky_ecr.repository_url
}

output "alb_dns_name" {
  description = "Existing Application Load Balancer DNS name"
  value       = module.alb.dns_name
}

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = module.alb.security_group_id
}


output "eticket_target_group_arn" {
  description = "eTicket target group ARN"
  value       = module.alb.target_groups["app"].arn
}

output "sticky_target_group_arn" {
  description = "Sticky Notes target group ARN"
  value       = module.alb.target_groups["sticky"].arn
}


output "ecs_cluster_name" {
  description = "Existing ECS cluster name"
  value       = "${var.name}-cluster"
}


output "ecs_service_name" {
  description = "Existing eTicket ECS service name"
  value       = "${var.name}-service"
}


output "sticky_ecs_service_name" {
  description = "Sticky Notes ECS service name"
  value       = "sticky-notes-service"
}


output "sns_topic_arn" {
  description = "SNS topic ARN"
  value       = module.sns.topic_arn
}