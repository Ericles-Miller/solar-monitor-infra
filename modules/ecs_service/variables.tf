variable "ecs_service_name" {
  type        = string
  description = "Nome do serviço e da família da task definition (ex.: solar-monitor-dev-api)"

  # Os papéis IAM ganham -execucao e -tarefa, e o nome do papel tem no máximo 64 caracteres.
  validation {
    condition     = can(regex("^[a-z0-9-]{1,55}$", var.ecs_service_name))
    error_message = "Use até 55 caracteres: letras minúsculas, números e hífens."
  }
}

variable "ecs_service_cluster_arn" {
  type        = string
  description = "Cluster ECS"
}

variable "ecs_service_image" {
  type        = string
  description = "Imagem com a tag (ex.: <repositório>:<commit>)"
}

variable "ecs_service_container_name" {
  type        = string
  description = "Nome do contêiner (usado no ECS Exec e no registro no ALB)"
  default     = "app"
}

variable "ecs_service_container_port" {
  type        = number
  description = "Porta do contêiner"
}

variable "ecs_service_cpu" {
  type        = number
  description = "CPU da tarefa (256 = 0,25 vCPU, 512 = 0,5 vCPU)"
}

variable "ecs_service_memory" {
  type        = number
  description = "Memória da tarefa em MB (512, 1024...)"
}

variable "ecs_service_cpu_architecture" {
  type        = string
  description = "Arquitetura da imagem. ARM64 (Graviton) sai ~20% mais barato e é o que o Mac com chip Apple gera"
  default     = "ARM64"

  validation {
    condition     = contains(["ARM64", "X86_64"], var.ecs_service_cpu_architecture)
    error_message = "Use ARM64 ou X86_64."
  }
}

variable "ecs_service_environment" {
  type        = map(string)
  description = "Variáveis comuns do contêiner (nunca segredos)"
  default     = {}
}

variable "ecs_service_secrets" {
  type        = map(string)
  description = "Segredos: nome da variável => ARN do parâmetro no Parameter Store"
  default     = {}
}

variable "ecs_service_task_policy_json" {
  type        = string
  description = "Política do papel da tarefa (o que o código pode fazer na AWS); null = nenhuma"
  default     = null
}

variable "ecs_service_log_group_name" {
  type        = string
  description = "Grupo de log do CloudWatch (MS-88)"
}

variable "ecs_service_region" {
  type        = string
  description = "Região, para o driver de log"
}

variable "ecs_service_subnet_ids" {
  type        = list(string)
  description = "Sub-redes das tarefas"
}

variable "ecs_service_security_group_ids" {
  type        = list(string)
  description = "Security groups das tarefas"
}

variable "ecs_service_assign_public_ip" {
  type        = bool
  description = "IP público na tarefa: sem NAT, é por ele que a tarefa sai para a internet (ECR, Sungrow, SES)"
  default     = true
}

variable "ecs_service_target_group_arn" {
  type        = string
  description = "Target group do ALB"
}

variable "ecs_service_desired_count" {
  type        = number
  description = "Quantas tarefas. O backend tem que ter 1 (o coletor roda no processo); 0 pausa o serviço"
  default     = 1

  validation {
    condition     = var.ecs_service_desired_count >= 0 && floor(var.ecs_service_desired_count) == var.ecs_service_desired_count
    error_message = "Informe um número inteiro de tarefas, a partir de 0."
  }
}

variable "ecs_service_deployment_minimum_healthy_percent" {
  type        = number
  description = "Mínimo saudável durante o deploy. 0 com máximo 100: a tarefa antiga sai antes da nova"
  default     = 0
}

variable "ecs_service_deployment_maximum_percent" {
  type        = number
  description = "Máximo durante o deploy. 100: nunca duas tarefas ao mesmo tempo"
  default     = 100
}

variable "ecs_service_health_check_path" {
  type        = string
  description = "Rota que responde 200 com o serviço de pé (ex.: /health); null = sem health check no contêiner"
  default     = null
}

variable "ecs_service_health_check_grace_period_seconds" {
  type        = number
  description = "Tempo para o serviço subir antes de o ALB contar o health check (o backend roda as migrations ao subir)"
  default     = 120
}

variable "ecs_service_enable_execute_command" {
  type        = bool
  description = "Liga o ECS Exec (shell na tarefa)"
  default     = false
}

variable "ecs_service_tags" {
  type        = map(string)
  description = "Tags de criação, além das default_tags do provider"
  default     = {}
}
