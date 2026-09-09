output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecs_cluster_name" {
  value = "app-cluster"
}

output "ecs_service_name" {
  value = "eticket-app-service"
}

output "alb_dns_name" {
  value = module.alb.dns_name
}

output "eticket_url" {
  value = "http://${module.alb.dns_name}/eticket"
}

output "sns_topic_arn" {
  value = module.sns.topic_arn
}

output "cloudwatch_metric_alarm_arns" {
  value = module.cloudwatch.cloudwatch_metric_alarm_arns
}

output "cloudwatch_metric_alarm_ids" {
  value = module.cloudwatch.cloudwatch_metric_alarm_ids
}