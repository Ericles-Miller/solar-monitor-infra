variable "ecs_cluster_name" {
  type        = string
  description = "Nome do cluster (ex.: solar-monitor-dev)"
}

variable "ecs_cluster_container_insights" {
  type        = bool
  description = "Liga o Container Insights (métricas pagas por contêiner)"
  default     = false
}

variable "ecs_cluster_log_services" {
  type        = list(string)
  description = "Serviços que ganham um grupo de log /ecs/<cluster>/<serviço>"
  default     = ["api", "web"]
}

variable "ecs_cluster_log_retention_days" {
  type        = number
  description = "Por quantos dias o CloudWatch guarda os logs"
  default     = 14

  # Valores aceitos pelo CloudWatch Logs (até 1 ano).
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.ecs_cluster_log_retention_days)
    error_message = "Use uma retenção aceita pelo CloudWatch: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180 ou 365 dias."
  }
}

variable "ecs_cluster_tags" {
  type        = map(string)
  description = "Tags de criação, além das default_tags do provider"
  default     = {}
}
