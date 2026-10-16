output "repository_url" {
  value       = aws_ecr_repository.main.repository_url
  sensitive   = false
  description = "Endereço do repositório, para o docker push e para a task definition"
}

output "repository_arn" {
  value       = aws_ecr_repository.main.arn
  sensitive   = false
  description = "ARN do repositório"
}

output "repository_name" {
  value       = aws_ecr_repository.main.name
  sensitive   = false
  description = "Nome do repositório"
}
