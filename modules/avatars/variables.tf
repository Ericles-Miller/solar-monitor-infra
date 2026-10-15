variable "avatars_bucket_name" {
  type        = string
  description = "Nome do bucket. É único no mundo todo: o ambiente passa o id da conta no nome"

  # Regras de nome do S3 (sem pontos, para o HTTPS de <bucket>.s3.<região>.amazonaws.com valer).
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.avatars_bucket_name))
    error_message = "Use de 3 a 63 caracteres: letras minúsculas, números e hífens, começando e terminando com letra ou número."
  }
}

variable "avatars_region" {
  type        = string
  description = "Região do bucket, para montar o endereço público"
}

variable "avatars_public_prefix" {
  type        = string
  description = "Prefixo com leitura pública. O backend grava os avatares em avatars/"
  default     = "avatars/"

  validation {
    condition     = can(regex("^[a-z0-9-]+/$", var.avatars_public_prefix))
    error_message = "O prefixo precisa terminar com / e não pode começar com / (ex.: avatars/)."
  }
}

variable "avatars_tags" {
  type        = map(string)
  description = "Tags de criação, além das default_tags do provider"
  default     = {}
}
