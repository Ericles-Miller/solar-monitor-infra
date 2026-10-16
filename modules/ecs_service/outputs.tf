output "service_name" {
  value       = aws_ecs_service.main.name
  sensitive   = false
  description = "Nome do serviço ECS"
}

output "container_name" {
  value       = var.ecs_service_container_name
  sensitive   = false
  description = "Nome do contêiner (para o ECS Exec: --container)"
}

output "task_definition_arn" {
  value       = aws_ecs_task_definition.main.arn
  sensitive   = false
  description = "Task definition em uso"
}

output "execution_role_arn" {
  value       = aws_iam_role.execution.arn
  sensitive   = false
  description = "Papel de execução (puxar a imagem, logs, segredos)"
}

output "task_role_arn" {
  value       = aws_iam_role.task.arn
  sensitive   = false
  description = "Papel da tarefa (o que o código pode fazer na AWS)"
}
