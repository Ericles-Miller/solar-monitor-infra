variable "database_name_prefix" {
  type        = string
  description = "Prefixo dos nomes (ex.: solar-monitor-dev)"
}

variable "database_subnet_ids" {
  type        = list(string)
  description = "Sub-redes privadas, em zonas diferentes (o RDS exige pelo menos 2 no grupo)"

  validation {
    condition     = length(var.database_subnet_ids) >= 2
    error_message = "O grupo de sub-redes do RDS precisa de pelo menos 2 sub-redes, em zonas diferentes."
  }
}

variable "database_security_group_id" {
  type        = string
  description = "Security group do banco (só o backend entra)"
}

variable "database_engine_version" {
  type        = string
  description = "Versão principal do PostgreSQL. A mesma do docker-compose local; o suporte padrão da AWS ao 15 vai até 29/02/2028"
  default     = "15"
}

variable "database_instance_class" {
  type        = string
  description = "Tamanho da instância"
  default     = "db.t4g.micro"
}

variable "database_allocated_storage_gb" {
  type        = number
  description = "Disco em GB (gp3)"
  default     = 20

  validation {
    condition     = var.database_allocated_storage_gb >= 20
    error_message = "O gp3 do RDS começa em 20 GB."
  }
}

variable "database_db_name" {
  type        = string
  description = "Banco criado junto com a instância (DB_NAME do backend). As tabelas vêm das migrations"
  default     = "solar_monitor"
}

variable "database_username" {
  type        = string
  description = "Usuário principal (DB_USERNAME do backend)"
  default     = "solar_monitor"
}

variable "database_port" {
  type        = number
  description = "Porta do PostgreSQL"
  default     = 5432
}

variable "database_backup_retention_days" {
  type        = number
  description = "Dias de backup automático"
  default     = 7

  validation {
    condition     = var.database_backup_retention_days >= 1 && var.database_backup_retention_days <= 35
    error_message = "O RDS aceita de 1 a 35 dias de backup (0 desligaria o backup)."
  }
}

variable "database_password_version" {
  type        = number
  description = "Aumente para gerar uma senha nova (no banco e no Parameter Store) e depois reinicie o backend"
  default     = 1

  validation {
    condition     = var.database_password_version >= 1 && floor(var.database_password_version) == var.database_password_version
    error_message = "A versão da senha é um número inteiro a partir de 1."
  }
}

variable "database_password_parameter_name" {
  type        = string
  description = "Parâmetro SecureString com a senha (ex.: /solar-monitor/dev/DB_PASSWORD)"

  validation {
    condition     = startswith(var.database_password_parameter_name, "/")
    error_message = "O nome do parâmetro começa com / (ex.: /solar-monitor/dev/DB_PASSWORD)."
  }
}

variable "database_tags" {
  type        = map(string)
  description = "Tags de criação, além das default_tags do provider"
  default     = {}
}
