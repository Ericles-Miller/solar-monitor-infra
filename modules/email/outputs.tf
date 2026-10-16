output "smtp_host" {
  value       = "email-smtp.${var.email_region}.amazonaws.com"
  sensitive   = false
  description = "Servidor SMTP do SES (MAIL_HOST do backend)"
}

output "smtp_port" {
  value       = 587
  sensitive   = false
  description = "Porta SMTP com STARTTLS (MAIL_PORT do backend; MAIL_SECURE=false)"
}

output "mail_from" {
  value       = "${var.email_sender_name} <${var.email_sender_address}>"
  sensitive   = false
  description = "Remetente (MAIL_FROM do backend)"
}

output "smtp_user_name" {
  value       = aws_iam_user.smtp.name
  sensitive   = false
  description = "Usuário IAM do SMTP (a chave dele é gerada por scripts/ses-smtp-credentials.sh)"
}

output "parameter_names" {
  value       = { for name, parameter in aws_ssm_parameter.smtp : name => parameter.name }
  sensitive   = false
  description = "Parâmetros MAIL_USER e MAIL_PASSWORD, lidos pela task definition do backend (MS-28)"
}

output "parameter_arns" {
  value       = { for name, parameter in aws_ssm_parameter.smtp : name => parameter.arn }
  sensitive   = false
  description = "MAIL_USER e MAIL_PASSWORD => ARN do parâmetro (bloco secrets da task definition, MS-28)"
}

output "verified_identities" {
  value       = concat([var.email_sender_address], sort(tolist(local.test_recipients)))
  sensitive   = false
  description = "Endereços que precisam clicar no link da AWS para o SES entregar no sandbox"
}
