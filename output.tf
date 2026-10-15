output "account_id" {
  value       = data.aws_caller_identity.current.account_id
  sensitive   = false
  description = "Conta da AWS onde o ambiente foi criado"
}

output "region" {
  value       = var.aws_region
  sensitive   = false
  description = "Região do ambiente"
}

output "budget_name" {
  value       = module.budget.budget_name
  sensitive   = false
  description = "Nome do orçamento com o alerta de custo"
}
