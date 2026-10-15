variable "backend_secrets_parameter_prefix" {
  type        = string
  description = "Prefixo dos parâmetros (ex.: /solar-monitor/dev)"

  validation {
    condition     = startswith(var.backend_secrets_parameter_prefix, "/") && !endswith(var.backend_secrets_parameter_prefix, "/")
    error_message = "O prefixo começa com / e não termina com / (ex.: /solar-monitor/dev)."
  }
}

variable "backend_secrets_jwt_version" {
  type        = number
  description = "Aumente para gerar segredos JWT novos (depois reinicie o backend; quem estiver logado entra de novo)"
  default     = 1

  validation {
    condition     = var.backend_secrets_jwt_version >= 1 && floor(var.backend_secrets_jwt_version) == var.backend_secrets_jwt_version
    error_message = "A versão é um número inteiro a partir de 1."
  }
}

variable "backend_secrets_tags" {
  type        = map(string)
  description = "Tags de criação, além das default_tags do provider"
  default     = {}
}
