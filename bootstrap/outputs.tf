output "state_bucket" {
  description = "Nome do bucket do estado: vai no envs/<ambiente>/backend.hcl."
  value       = aws_s3_bucket.state.bucket
}

output "region" {
  description = "Região do bucket do estado."
  value       = var.region
}
