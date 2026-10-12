# Roda sem acesso à AWS: terraform -chdir=modules/budget init && terraform -chdir=modules/budget test
mock_provider "aws" {}

variables {
  name         = "solar-monitor-mensal"
  limit_usd    = 50
  alert_emails = ["alertas@exemplo.com"]
}

run "filtra_pela_tag_do_projeto" {
  command = plan

  variables {
    cost_filter_tag = {
      key   = "Project"
      value = "solar-monitor"
    }
  }

  assert {
    condition     = toset(one(aws_budgets_budget.monthly.cost_filter).values) == toset(["user:Project$solar-monitor"])
    error_message = "O filtro de custo precisa estar no formato user:<chave>$<valor>."
  }

  assert {
    condition     = aws_budgets_budget.monthly.limit_amount == "50.0"
    error_message = "O limite precisa ir com uma casa decimal, como a AWS devolve."
  }

  assert {
    condition     = length(aws_budgets_budget.monthly.notification) == 3
    error_message = "Precisa avisar em 80% e 100% do real e em 100% do previsto."
  }
}

run "sem_filtro_conta_a_conta_inteira" {
  command = plan

  assert {
    condition     = length(aws_budgets_budget.monthly.cost_filter) == 0
    error_message = "Sem cost_filter_tag, o orçamento não pode ter filtro."
  }
}

run "recusa_lista_de_emails_vazia" {
  command = plan

  variables {
    alert_emails = []
  }

  expect_failures = [var.alert_emails]
}

run "recusa_email_invalido" {
  command = plan

  variables {
    alert_emails = ["nao-e-email"]
  }

  expect_failures = [var.alert_emails]
}

run "recusa_limite_zero" {
  command = plan

  variables {
    limit_usd = 0
  }

  expect_failures = [var.limit_usd]
}
