output "parameter_arns" {
  value = merge(
    {
      JWT_ACCESS_SECRET  = aws_ssm_parameter.jwt_access.arn
      JWT_REFRESH_SECRET = aws_ssm_parameter.jwt_refresh.arn
      MAIL_PASSWORD      = aws_ssm_parameter.mail_password.arn
    },
    { for name, parameter in aws_ssm_parameter.sungrow : name => parameter.arn },
  )
  sensitive   = false
  description = "Variável do backend => ARN do parâmetro (bloco secrets da task definition)"
}

output "sungrow_parameter_names" {
  value       = sort([for parameter in aws_ssm_parameter.sungrow : parameter.name])
  sensitive   = false
  description = "Parâmetros que scripts/backend-secrets.sh preenche"
}
