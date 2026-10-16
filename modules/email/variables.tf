variable "email_name_prefix" {
  type        = string
  description = "Prefixo dos nomes (ex.: solar-monitor-dev)"
}

variable "email_region" {
  type        = string
  description = "Região do SES, para montar o endereço SMTP"
}

variable "email_sender_address" {
  type        = string
  description = "Endereço do remetente (MAIL_FROM). Recebe um link da AWS para confirmar"

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.email_sender_address))
    error_message = "Informe um e-mail válido para o remetente."
  }
}

variable "email_sender_name" {
  type        = string
  description = "Nome que aparece como remetente"
  default     = "Monitoramento de Usinas Solares"
}

variable "email_test_recipients" {
  type        = list(string)
  description = "Destinatários de teste enquanto o SES está no sandbox (cada um recebe um link da AWS para confirmar)"
  default     = []

  validation {
    condition     = alltrue([for email in var.email_test_recipients : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email))])
    error_message = "Informe e-mails válidos nos destinatários de teste."
  }
}

variable "email_parameter_prefix" {
  type        = string
  description = "Prefixo dos parâmetros MAIL_USER e MAIL_PASSWORD (ex.: /solar-monitor/dev)"

  validation {
    condition     = startswith(var.email_parameter_prefix, "/") && !endswith(var.email_parameter_prefix, "/")
    error_message = "O prefixo começa com / e não termina com / (ex.: /solar-monitor/dev)."
  }
}

variable "email_tags" {
  type        = map(string)
  description = "Tags de criação, além das default_tags do provider"
  default     = {}
}
