variable "cdn_name" {
  type        = string
  description = "Nome da distribuição e prefixo da política de cache (ex.: solar-monitor-dev-web)"
}

variable "cdn_origin_domain_name" {
  type        = string
  description = "DNS do ALB que recebe as requisições"
}

variable "cdn_origin_http_port" {
  type        = number
  description = "Porta HTTP do listener do ALB (80 para o front, 8080 para a API)"

  validation {
    condition     = var.cdn_origin_http_port == 80 || (var.cdn_origin_http_port >= 1024 && var.cdn_origin_http_port <= 65535)
    error_message = "O CloudFront só aceita a porta 80 ou uma porta entre 1024 e 65535."
  }
}

variable "cdn_tags" {
  type        = map(string)
  description = "Tags de criação, além das default_tags do provider"
  default     = {}
}
