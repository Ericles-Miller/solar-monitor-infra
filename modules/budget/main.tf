# Orçamento mensal com alerta por e-mail: 80% e 100% do gasto real e 100% do previsto para o mês.

locals {
  notifications = [
    { threshold = 80, type = "ACTUAL" },
    { threshold = 100, type = "ACTUAL" },
    { threshold = 100, type = "FORECASTED" },
  ]
}

resource "aws_budgets_budget" "monthly" {
  name         = var.name
  budget_type  = "COST"
  limit_amount = format("%.1f", var.limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "cost_filter" {
    for_each = var.cost_filter_tag == null ? [] : [var.cost_filter_tag]

    content {
      name = "TagKeyValue"
      # Formato do Budgets para tag criada pelo usuário: user:<chave>$<valor>.
      values = [format("user:%s$%s", cost_filter.value.key, cost_filter.value.value)]
    }
  }

  dynamic "notification" {
    for_each = local.notifications

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value.threshold
      threshold_type             = "PERCENTAGE"
      notification_type          = notification.value.type
      subscriber_email_addresses = var.alert_emails
    }
  }
}
