output "bucket_name" {
  value       = aws_s3_bucket.avatars.bucket
  sensitive   = false
  description = "Nome do bucket (S3_BUCKET do backend)"
}

output "public_url" {
  value       = "https://${aws_s3_bucket.avatars.bucket}.s3.${var.avatars_region}.amazonaws.com"
  sensitive   = false
  description = "De onde o navegador lê os avatares, sem barra no final (S3_PUBLIC_URL do backend)"
}

output "bucket_arn" {
  value       = local.bucket_arn
  sensitive   = false
  description = "ARN do bucket"
}

output "public_objects_arn" {
  value       = local.public_objects_arn
  sensitive   = false
  description = "ARN dos avatares: o papel da tarefa do backend (MS-28) ganha s3:PutObject e s3:DeleteObject nele"
}
