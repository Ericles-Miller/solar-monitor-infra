variable "name" {
  description = "Nome do orçamento no AWS Budgets."
  type        = string
}

variable "limit_usd" {
  description = "Limite mensal em dólares."
  type        = number

  validation {
    condition     = var.limit_usd > 0
    error_message = "O limite precisa ser maior que zero."
  }
}

variable "alert_emails" {
  description = "Quem recebe os alertas de custo."
  type        = list(string)

  validation {
    condition     = length(var.alert_emails) > 0 && alltrue([for email in var.alert_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email))])
    error_message = "Informe ao menos um e-mail válido."
  }
}

variable "cost_filter_tag" {
  description = "Conta só o custo dos recursos com esta tag. null = conta inteira. A tag precisa estar ativada como tag de alocação de custo no Billing."
  type = object({
    key   = string
    value = string
  })
  default = null
}
