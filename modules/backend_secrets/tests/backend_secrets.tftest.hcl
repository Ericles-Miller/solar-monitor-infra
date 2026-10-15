# Roda sem acesso à AWS: terraform -chdir=modules/backend_secrets init && terraform -chdir=modules/backend_secrets test
# Só o provider da AWS é simulado; o random roda de verdade (é local).
mock_provider "aws" {}

variables {
  backend_secrets_parameter_prefix = "/solar-monitor/dev"
}

run "seis_segredos_no_parameter_store" {
  command = plan

  assert {
    condition     = toset(keys(output.parameter_arns)) == toset(["JWT_ACCESS_SECRET", "JWT_REFRESH_SECRET", "SUNGROW_APPKEY", "SUNGROW_ACCESS_KEY", "SUNGROW_USER_ACCOUNT", "SUNGROW_USER_PASSWORD"])
    error_message = "O backend precisa dos dois JWT e das quatro credenciais da Sungrow."
  }

  assert {
    condition     = aws_ssm_parameter.jwt_access.name == "/solar-monitor/dev/JWT_ACCESS_SECRET" && aws_ssm_parameter.jwt_refresh.name == "/solar-monitor/dev/JWT_REFRESH_SECRET"
    error_message = "Os JWT ficam em /solar-monitor/dev."
  }

  assert {
    condition     = alltrue([for parameter in concat([aws_ssm_parameter.jwt_access, aws_ssm_parameter.jwt_refresh], values(aws_ssm_parameter.sungrow)) : parameter.type == "SecureString"])
    error_message = "Todo segredo é SecureString."
  }
}

run "nenhum_valor_no_estado" {
  command = plan

  assert {
    condition     = alltrue([for parameter in concat([aws_ssm_parameter.jwt_access, aws_ssm_parameter.jwt_refresh], values(aws_ssm_parameter.sungrow)) : parameter.value_wo == null])
    error_message = "Os valores são write-only: não vão ao estado."
  }

  assert {
    condition     = aws_ssm_parameter.jwt_access.value_wo_version == 1 && aws_ssm_parameter.jwt_refresh.value_wo_version == 1
    error_message = "Os JWT começam na versão 1."
  }
}

run "nova_versao_troca_os_dois_jwt" {
  command = plan

  variables {
    backend_secrets_jwt_version = 2
  }

  assert {
    condition     = aws_ssm_parameter.jwt_access.value_wo_version == 2 && aws_ssm_parameter.jwt_refresh.value_wo_version == 2
    error_message = "Trocar a versão gera os dois segredos de novo."
  }

  assert {
    condition     = alltrue([for parameter in values(aws_ssm_parameter.sungrow) : parameter.value_wo_version == 1])
    error_message = "A versão dos JWT não mexe nas credenciais da Sungrow."
  }
}

run "recusa_prefixo_sem_barra" {
  command = plan

  variables {
    backend_secrets_parameter_prefix = "solar-monitor/dev"
  }

  expect_failures = [var.backend_secrets_parameter_prefix]
}
