output "account_id" {
  description = "Conta da AWS onde o ambiente foi criado."
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "Região do ambiente."
  value       = var.region
}

output "budget_name" {
  description = "Nome do orçamento com o alerta de custo."
  value       = module.budget.name
}
