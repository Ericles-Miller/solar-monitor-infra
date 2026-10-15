# Ambiente dev: backend e frontend do Solar Monitor.
# Arquitetura e decisões: docs/arquitetura/09-infra-terraform-dev.md.

locals {
  project = "solar-monitor"
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
