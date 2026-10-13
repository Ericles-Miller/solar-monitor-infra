variable "budget_name" {
  type        = string
  description = "Nome do orçamento no AWS Budgets"
}

variable "budget_limit_usd" {
  type        = number
  description = "Limite mensal em dólares"

  validation {
    condition     = var.budget_limit_usd > 0
    error_message = "O limite precisa ser maior que zero."
  }
}

variable "budget_alert_emails" {
  type        = list(string)
  description = "Quem recebe os alertas de custo"

  validation {
    condition     = length(var.budget_alert_emails) > 0 && alltrue([for email in var.budget_alert_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email))])
    error_message = "Informe ao menos um e-mail válido."
  }
}

variable "budget_cost_filter_tag" {
  type = object({
    key   = string
    value = string
  })
  default     = null
  description = "Conta só o custo dos recursos com esta tag. null = conta inteira. A tag precisa estar ativada como tag de alocação de custo no Billing"
}

variable "budget_tags" {
  type        = map(string)
  default     = {}
  description = "Tags de criação, além das default_tags do provider"
}
