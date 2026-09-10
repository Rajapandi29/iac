output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}



output "alb_dns_name" {
  value = module.alb.dns_name
}

output "application_url" {
  value = "http://${module.alb.dns_name}/"
}

output "backend_url" {
  value = "http://${module.alb.dns_name}/backend"
}



output "streamlit_ecr_repository" {
  value = module.ecr_streamlit.repository_url
}

output "fastapi_ecr_repository" {
  value = module.ecr_fastapi.repository_url
}


output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  value = module.ecs.cluster_arn
}

output "streamlit_service" {
  value = module.ecs.services["streamlit"]
}

output "fastapi_service" {
  value = module.ecs.services["fastapi"]
}



output "ecs_task_execution_role_arn" {
  value = module.ecs.task_exec_iam_role_arn
}

output "streamlit_ecr_url" {
  value = module.ecr_streamlit.repository_url
}

output "fastapi_ecr_url" {
  value = module.ecr_fastapi.repository_url
}