# Ambiente dev: backend e frontend do Solar Monitor.
# Arquitetura e decisões: docs/arquitetura/09-infra-terraform-dev.md.

locals {
  project     = "solar-monitor"
  name_prefix = "${local.project}-${var.environment}"

  # Sem domínio, o front sai na porta 80 do ALB (a MS-30 troca por https://dev.<domínio>).
  frontend_url = "http://${module.alb.alb_dns_name}"

  # Variáveis comuns do backend (07-deploy-backend.md §3). NODE_ENV=production vem do Dockerfile. Segredo nunca
  # entra aqui: vai no bloco secrets, pelo Parameter Store.
  backend_environment = {
    PORT                           = tostring(var.backend_port)
    TZ                             = "America/Sao_Paulo"
    TRUST_PROXY_HOPS               = "1"
    DB_HOST                        = module.database.address
    DB_PORT                        = tostring(module.database.port)
    DB_NAME                        = module.database.db_name
    DB_USERNAME                    = module.database.username
    DB_SSL                         = "true"
    CORS_ORIGINS                   = local.frontend_url
    FRONTEND_URL                   = local.frontend_url
    MAIL_HOST                      = module.email.smtp_host
    MAIL_PORT                      = tostring(module.email.smtp_port)
    MAIL_SECURE                    = "false"
    MAIL_FROM                      = module.email.mail_from
    APP_NAME                       = var.app_name
    AWS_REGION                     = var.aws_region
    S3_BUCKET                      = module.avatars.bucket_name
    S3_PUBLIC_URL                  = module.avatars.public_url
    SUNGROW_GATEWAY_URL            = var.sungrow_gateway_url
    COLLECTOR_INTERVAL_MINUTES     = tostring(var.collector_interval_minutes)
    COLLECTOR_ALERT_AFTER_FAILURES = tostring(var.collector_alert_after_failures)
  }
}

# Conta só os recursos com a tag Project = solar-monitor, para não misturar com outros projetos da conta.
module "budget" {
  source              = "./modules/budget"
  budget_name         = "${local.project}-${var.environment}-mensal"
  budget_limit_usd    = var.budget_limit_usd
  budget_alert_emails = var.budget_alert_emails
  budget_cost_filter_tag = {
    key   = "Project"
    value = local.project
  }
}

# Rede, security groups, ALB e cluster ECS (MS-88). Sem domínio: :80 -> frontend e :8080 -> backend (até a MS-30).
module "network" {
  source                     = "./modules/network"
  network_name_prefix        = local.name_prefix
  network_alb_listener_ports = [var.frontend_listener_port, var.backend_listener_port]
  network_backend_port       = var.backend_port
  network_frontend_port      = var.frontend_port
}

module "alb" {
  source                     = "./modules/alb"
  alb_name_prefix            = local.name_prefix
  alb_vpc_id                 = module.network.vpc_id
  alb_subnet_ids             = module.network.public_subnet_ids
  alb_security_group_id      = module.network.alb_security_group_id
  alb_backend_port           = var.backend_port
  alb_frontend_port          = var.frontend_port
  alb_frontend_listener_port = var.frontend_listener_port
  alb_backend_listener_port  = var.backend_listener_port
}

module "ecs_cluster" {
  source           = "./modules/ecs_cluster"
  ecs_cluster_name = local.name_prefix
}

# Avatares dos usuários (MS-90). O id da conta deixa o nome único no mundo todo, como no bucket do estado.
module "avatars" {
  source              = "./modules/avatars"
  avatars_bucket_name = "${local.name_prefix}-avatars-${data.aws_caller_identity.current.account_id}"
  avatars_region      = var.aws_region
}

# Banco do backend (MS-89). A senha não fica no estado e o RDS não a troca sozinho (decisão de 15/10/2026).
module "database" {
  source                           = "./modules/database"
  database_name_prefix             = local.name_prefix
  database_subnet_ids              = module.network.private_subnet_ids
  database_security_group_id       = module.network.database_security_group_id
  database_password_parameter_name = "/${local.project}/${var.environment}/DB_PASSWORD"
}

# E-mail do backend pelo SES (MS-91). Sem domínio, o remetente é um endereço verificado (por enquanto, só para teste).
module "email" {
  source                 = "./modules/email"
  email_name_prefix      = local.name_prefix
  email_region           = var.aws_region
  email_sender_address   = var.mail_sender_email
  email_test_recipients  = var.mail_test_recipients
  email_parameter_prefix = "/${local.project}/${var.environment}"
}

# Backend no ECS (MS-28): imagem no ECR, segredos no Parameter Store e uma tarefa atrás do ALB (:8080 até a MS-30).
module "backend_ecr" {
  source              = "./modules/ecr"
  ecr_repository_name = "${local.project}-api"
}

module "backend_secrets" {
  source                           = "./modules/backend_secrets"
  backend_secrets_parameter_prefix = "/${local.project}/${var.environment}"
}

module "backend" {
  source                             = "./modules/ecs_service"
  ecs_service_name                   = "${local.name_prefix}-api"
  ecs_service_cluster_arn            = module.ecs_cluster.cluster_arn
  ecs_service_image                  = "${module.backend_ecr.repository_url}:${var.backend_image_tag}"
  ecs_service_container_name         = "api"
  ecs_service_container_port         = var.backend_port
  ecs_service_cpu                    = var.backend_cpu
  ecs_service_memory                 = var.backend_memory
  ecs_service_log_group_name         = module.ecs_cluster.log_group_names["api"]
  ecs_service_region                 = var.aws_region
  ecs_service_subnet_ids             = module.network.public_subnet_ids
  ecs_service_security_group_ids     = [module.network.backend_security_group_id]
  ecs_service_target_group_arn       = module.alb.backend_target_group_arn
  ecs_service_health_check_path      = "/health"
  ecs_service_enable_execute_command = true
  ecs_service_environment            = local.backend_environment

  ecs_service_secrets = merge(module.backend_secrets.parameter_arns, {
    DB_PASSWORD   = module.database.password_parameter_arn
    MAIL_USER     = module.email.parameter_arns["MAIL_USER"]
    MAIL_PASSWORD = module.email.parameter_arns["MAIL_PASSWORD"]
  })

  # O backend grava e apaga avatares; nada além de avatars/*.
  ecs_service_task_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = module.avatars.public_objects_arn
      },
    ]
  })
}

# Deploy do backend pelo GitHub Actions (MS-94): só a develop do solar-monitor publica no dev.
module "backend_github_deploy" {
  source                           = "./modules/github_deploy"
  github_deploy_name               = "${local.name_prefix}-github-api"
  github_deploy_repository         = "${var.github_owner}/solar-monitor"
  github_deploy_ecr_repository_arn = module.backend_ecr.repository_arn
  github_deploy_ecs_service_arn    = module.backend.service_arn
  github_deploy_pass_role_arns     = [module.backend.execution_role_arn, module.backend.task_role_arn]
}
