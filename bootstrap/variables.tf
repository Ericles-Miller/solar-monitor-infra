variable "aws_profile" {
  type        = string
  description = "Perfil da AWS CLI a ser usado"
  default     = "ericles-dev"
}

variable "aws_region" {
  type        = string
  description = "Região AWS onde fica o bucket do estado"
  default     = "sa-east-1"
}
