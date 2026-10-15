output "address" {
  value       = aws_db_instance.main.address
  sensitive   = false
  description = "Endereço do banco (DB_HOST do backend)"
}

output "port" {
  value       = aws_db_instance.main.port
  sensitive   = false
  description = "Porta do banco (DB_PORT do backend)"
}

output "db_name" {
  value       = aws_db_instance.main.db_name
  sensitive   = false
  description = "Nome do banco (DB_NAME do backend)"
}

output "username" {
  value       = aws_db_instance.main.username
  sensitive   = false
  description = "Usuário do banco (DB_USERNAME do backend). Não é segredo: a senha é"
}

output "password_parameter_name" {
  value       = aws_ssm_parameter.password.name
  sensitive   = false
  description = "Parâmetro com a senha (DB_PASSWORD do backend, lido pela task definition da MS-28)"
}

output "password_parameter_arn" {
  value       = aws_ssm_parameter.password.arn
  sensitive   = false
  description = "ARN do parâmetro da senha, para o papel de execução da tarefa (MS-28) poder ler"
}
