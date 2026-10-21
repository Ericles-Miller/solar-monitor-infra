output "url" {
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
  sensitive   = false
  description = "Endereço HTTPS da distribuição"
}

output "distribution_id" {
  value       = aws_cloudfront_distribution.main.id
  sensitive   = false
  description = "ID da distribuição (para invalidar ou conferir no console)"
}
