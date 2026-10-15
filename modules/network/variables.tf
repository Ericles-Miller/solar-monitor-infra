variable "network_name_prefix" {
  type        = string
  description = "Prefixo dos nomes dos recursos (ex.: solar-monitor-dev)"
}

variable "network_vpc_cidr" {
  type        = string
  description = "Faixa de IPs da VPC. As sub-redes são /24 dentro dela"
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.network_vpc_cidr, 0)) && try(tonumber(split("/", var.network_vpc_cidr)[1]) <= 16, false)
    error_message = "Informe uma faixa CIDR válida de /16 ou maior (ex.: 10.0.0.0/16)."
  }
}

variable "network_az_count" {
  type        = number
  description = "Quantas zonas de disponibilidade usar. O ALB e o grupo de sub-redes do RDS exigem pelo menos 2"
  default     = 2

  validation {
    condition     = var.network_az_count >= 2 && var.network_az_count <= 3
    error_message = "Use 2 ou 3 zonas: o ALB e o RDS exigem pelo menos 2, e a região sa-east-1 tem 3."
  }
}

variable "network_alb_listener_ports" {
  type        = list(number)
  description = "Portas HTTP que o ALB abre para a internet (as dos listeners)"
}

variable "network_backend_port" {
  type        = number
  description = "Porta do container do backend"
}

variable "network_frontend_port" {
  type        = number
  description = "Porta do container do frontend"
}

variable "network_database_port" {
  type        = number
  description = "Porta do PostgreSQL"
  default     = 5432
}

variable "network_tags" {
  type        = map(string)
  description = "Tags de criação, além das default_tags do provider"
  default     = {}
}
