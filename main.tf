# Ambiente dev: backend e frontend do Solar Monitor.
# Arquitetura e decisões: docs/arquitetura/09-infra-terraform-dev.md.

locals {
  project     = "solar-monitor"
  name_prefix = "${local.project}-${var.environment}"
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
