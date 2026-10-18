variable "environment" {
  type        = string
  description = "Ambiente (por enquanto só dev)"
  default     = "dev"

  # O backend aponta para o estado do dev (providers.tf): outro valor renomearia e recriaria os recursos do dev.
  validation {
    condition     = var.environment == "dev"
    error_message = "Só o ambiente dev existe. O prod vai ter estado próprio."
  }
}

variable "aws_profile" {
  type        = string
  description = "Perfil da AWS CLI a ser usado"
  default     = "ericles-dev"
}

variable "aws_region" {
  type        = string
  description = "Região AWS"
  default     = "sa-east-1"
}

variable "budget_limit_usd" {
  type        = number
  description = "Limite mensal do alerta de custo, em dólares (decidido pelo Ericles em 12/10/2026)"
  default     = 50
}

variable "budget_alert_emails" {
  type        = list(string)
  description = "Quem recebe os alertas de custo. Vem de TF_VAR_budget_alert_emails, fora do repositório"
}

variable "backend_port" {
  type        = number
  description = "Porta do container do backend (PORT do NestJS)"
  default     = 3333
}

variable "frontend_port" {
  type        = number
  description = "Porta do container do frontend (Next.js)"
  default     = 3000
}

variable "frontend_listener_port" {
  type        = number
  description = "Porta HTTP pública do frontend no ALB"
  default     = 80
}

variable "backend_listener_port" {
  type        = number
  description = "Porta HTTP pública do backend no ALB, enquanto não há domínio (sai na MS-30)"
  default     = 8080
}

variable "mail_sender_email" {
  type        = string
  description = "Remetente dos e-mails do backend (MAIL_FROM). Vem de TF_VAR_mail_sender_email, fora do repositório"
}

variable "mail_test_recipients" {
  type        = list(string)
  description = "Destinatários de teste enquanto o SES está no sandbox. Vem de TF_VAR_mail_test_recipients, fora do repositório"
  default     = []
}

variable "backend_image_tag" {
  type        = string
  description = "Tag da imagem do backend no ECR (o commit curto do solar-monitor, MS-94). Vem de -var ou TF_VAR_backend_image_tag"

  validation {
    condition     = length(var.backend_image_tag) > 0 && var.backend_image_tag != "latest"
    error_message = "Informe a tag de uma imagem enviada ao ECR (o commit curto), nunca latest."
  }
}

variable "backend_cpu" {
  type        = number
  description = "CPU da tarefa do backend (512 = 0,5 vCPU)"
  default     = 512
}

variable "backend_memory" {
  type        = number
  description = "Memória da tarefa do backend, em MB"
  default     = 1024
}

variable "app_name" {
  type        = string
  description = "Nome da plataforma nos e-mails (APP_NAME do backend)"
  default     = "Monitoramento de Usinas Solares"
}

variable "sungrow_gateway_url" {
  type        = string
  description = "Gateway da API da Sungrow (SUNGROW_GATEWAY_URL do backend)"
  default     = "https://gateway.isolarcloud.com.hk"
}

variable "collector_interval_minutes" {
  type        = number
  description = "De quanto em quanto tempo o coletor busca as leituras na Sungrow"
  default     = 10
}

variable "collector_alert_after_failures" {
  type        = number
  description = "Quantos ciclos seguidos com falha até o coletor avisar no log"
  default     = 3
}

variable "github_owner" {
  type        = string
  description = "Dono dos repositórios no GitHub (o papel do deploy só aceita os repositórios dele)"
  default     = "Ericles-Miller"
}

variable "frontend_image_tag" {
  type        = string
  description = "Tag da imagem do front no ECR (o commit curto do solar-monitor-web). Vem de -var ou TF_VAR_frontend_image_tag"

  validation {
    condition     = length(var.frontend_image_tag) > 0 && var.frontend_image_tag != "latest"
    error_message = "Informe a tag de uma imagem enviada ao ECR (o commit curto), nunca latest."
  }
}

variable "frontend_cpu" {
  type        = number
  description = "CPU da tarefa do front (256 = 0,25 vCPU)"
  default     = 256
}

variable "frontend_memory" {
  type        = number
  description = "Memória da tarefa do front, em MB"
  default     = 512
}
