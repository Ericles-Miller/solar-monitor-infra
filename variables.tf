variable "environment" {
  type        = string
  description = "Ambiente (por enquanto só dev)"
  default     = "dev"

  # O backend aponta para o estado do dev (providers.tf): outro valor renomearia e recriaria os recursos do dev.
  validation {
    condition     = var.environment == "dev"
    error_message = "Só o ambiente dev existe. O prod vai ter estado próprio."
  }
}

variable "aws_profile" {
  type        = string
  description = "Perfil da AWS CLI a ser usado"
  default     = "ericles-dev"
}

variable "aws_region" {
  type        = string
  description = "Região AWS"
  default     = "sa-east-1"
}

variable "budget_limit_usd" {
  type        = number
  description = "Limite mensal do alerta de custo, em dólares (decidido pelo Ericles em 12/10/2026)"
  default     = 50
}

variable "budget_alert_emails" {
  type        = list(string)
  description = "Quem recebe os alertas de custo. Vem de TF_VAR_budget_alert_emails, fora do repositório"
}
