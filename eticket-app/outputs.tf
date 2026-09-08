
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}


output "ecr_repository_name" {
  description = "ECR repository name"
  value       = module.ecr.repository_name
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = module.ecr.repository_arn
}


output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.ecs.cluster_arn
}

output "ecs_services" {
  description = "ECS services"
  value       = module.ecs.services
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.alb.dns_name
}

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = module.alb.arn
}

output "application_url" {
  description = "Application URL"
  value       = "http://${module.alb.dns_name}"
}


output "sns_topic_arn" {
  description = "SNS alert topic ARN"
  value       = module.sns.topic_arn
}

output "sns_topic_name" {
  description = "SNS alert topic name"
  value       = module.sns.topic_name
}