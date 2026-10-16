output "role_arn" {
  value       = aws_iam_role.deploy.arn
  sensitive   = false
  description = "Papel do deploy (secret ROLE_ASSUME do repositório no GitHub)"
}
