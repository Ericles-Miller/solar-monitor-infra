output "budget_name" {
  value       = aws_budgets_budget.monthly.name
  sensitive   = false
  description = "Nome do orçamento"
}
