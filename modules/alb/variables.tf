variable "alb_name_prefix" {
  type        = string
  description = "Prefixo dos nomes (ex.: solar-monitor-dev). Nome de ALB e de target group tem no máximo 32 caracteres"

  validation {
    condition     = length(var.alb_name_prefix) <= 28
    error_message = "O prefixo pode ter no máximo 28 caracteres (o nome final ganha -alb, -api ou -web e o limite é 32)."
  }
}

variable "alb_vpc_id" {
  type        = string
  description = "VPC dos target groups"
}

variable "alb_subnet_ids" {
  type        = list(string)
  description = "Sub-redes públicas do ALB, em zonas diferentes"

  validation {
    condition     = length(var.alb_subnet_ids) >= 2
    error_message = "O ALB precisa de sub-redes em pelo menos 2 zonas."
  }
}

variable "alb_security_group_id" {
  type        = string
  description = "Security group do ALB"
}

variable "alb_backend_port" {
  type        = number
  description = "Porta do container do backend"
}

variable "alb_frontend_port" {
  type        = number
  description = "Porta do container do frontend"
}

variable "alb_frontend_listener_port" {
  type        = number
  description = "Porta HTTP pública do frontend"
}

variable "alb_backend_listener_port" {
  type        = number
  description = "Porta HTTP pública do backend, enquanto não há domínio"
}

variable "alb_deregistration_delay_seconds" {
  type        = number
  description = "Quanto o ALB espera as requisições em andamento antes de tirar uma tarefa do ar"
  default     = 30
}

variable "alb_tags" {
  type        = map(string)
  description = "Tags de criação, além das default_tags do provider"
  default     = {}
}
