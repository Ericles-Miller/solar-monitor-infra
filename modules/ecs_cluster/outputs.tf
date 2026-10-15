output "cluster_name" {
  value       = aws_ecs_cluster.main.name
  sensitive   = false
  description = "Nome do cluster ECS"
}

output "cluster_arn" {
  value       = aws_ecs_cluster.main.arn
  sensitive   = false
  description = "ARN do cluster ECS"
}

output "log_group_names" {
  value       = { for service, group in aws_cloudwatch_log_group.service : service => group.name }
  sensitive   = false
  description = "Grupo de log de cada serviço (api, web)"
}
