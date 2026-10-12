variable "region" {
  description = "Região da AWS do ambiente."
  type        = string
  default     = "sa-east-1"
}

variable "budget_limit_usd" {
  description = "Limite mensal do alerta de custo, em dólares."
  type        = number
}

variable "budget_alert_emails" {
  description = "Quem recebe os alertas de custo."
  type        = list(string)
}
