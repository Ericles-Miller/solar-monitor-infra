variable "github_deploy_name" {
  type        = string
  description = "Nome do papel (ex.: solar-monitor-dev-github-api)"
}

variable "github_deploy_repository" {
  type        = string
  description = "Repositório no GitHub, no formato dono/nome (ex.: Ericles-Miller/solar-monitor)"

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_deploy_repository))
    error_message = "Use o formato dono/nome (ex.: Ericles-Miller/solar-monitor)."
  }
}

variable "github_deploy_branches" {
  type        = list(string)
  description = "Branches que podem publicar (decisão de 16/10/2026: só a develop publica no dev)"
  default     = ["develop"]

  validation {
    condition     = length(var.github_deploy_branches) > 0 && !contains(var.github_deploy_branches, "*")
    error_message = "Informe ao menos uma branch, sem curinga."
  }
}

variable "github_deploy_ecr_repository_arn" {
  type        = string
  description = "Repositório do ECR para onde a imagem vai"
}

variable "github_deploy_ecs_service_arn" {
  type        = string
  description = "Serviço do ECS que o workflow atualiza"
}

variable "github_deploy_pass_role_arns" {
  type        = list(string)
  description = "Papéis de execução e da tarefa do serviço (a revisão nova da task definition aponta para eles)"
}

variable "github_deploy_tags" {
  type        = map(string)
  description = "Tags de criação, além das default_tags do provider"
  default     = {}
}
