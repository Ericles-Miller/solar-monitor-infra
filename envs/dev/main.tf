# Ambiente dev: backend e frontend do Solar Monitor.
# Arquitetura e decisões: docs/arquitetura/09-infra-terraform-dev.md.

locals {
  project     = "solar-monitor"
  environment = "dev"
  name_prefix = "${local.project}-${local.environment}"

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
    Repository  = "solar-monitor-infra"
  }
}

data "aws_caller_identity" "current" {}

# Conta só os recursos com a tag Project = solar-monitor, para não misturar com outros projetos da conta.
module "budget" {
  source = "../../modules/budget"

  name         = "${local.project}-mensal"
  limit_usd    = var.budget_limit_usd
  alert_emails = var.budget_alert_emails

  cost_filter_tag = {
    key   = "Project"
    value = local.project
  }
}
