output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecs_cluster_name" {
  value = "app-cluster"
}

output "ecs_service_name" {
  value = "sticky-notes-service"
}

output "alb_dns_name" {
  value = module.alb.dns_name
}

output "sticky_notes_url" {
  value = "http://${module.alb.dns_name}/sticky"
}
output "sns_topic_arn" {
  value = module.sns.topic_arn
}

output "cloudwatch_alarm_name" {
  value = module.cloudwatch.alarm_name
}