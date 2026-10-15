output "state_bucket" {
  value       = aws_s3_bucket.state.bucket
  sensitive   = false
  description = "Nome do bucket do estado: vai no backend do providers.tf da raiz"
}

output "region" {
  value       = var.aws_region
  sensitive   = false
  description = "Região do bucket do estado"
}
