variable "ecr_repository_name" {
  type        = string
  description = "Nome do repositório (ex.: solar-monitor-api)"

  validation {
    condition     = can(regex("^[a-z0-9]+([._-][a-z0-9]+)*$", var.ecr_repository_name))
    error_message = "Use letras minúsculas, números e . _ - entre eles (ex.: solar-monitor-api)."
  }
}

variable "ecr_keep_images" {
  type        = number
  description = "Quantas imagens guardar (as mais recentes)"
  default     = 10

  validation {
    condition     = var.ecr_keep_images >= 2
    error_message = "Guarde pelo menos 2 imagens: a atual e a anterior, para o rollback."
  }
}

variable "ecr_tags" {
  type        = map(string)
  description = "Tags de criação, além das default_tags do provider"
  default     = {}
}
