# Roda sem acesso à AWS: terraform -chdir=modules/email init && terraform -chdir=modules/email test
# command = apply com o provider simulado: não cria nada; os ARNs falsos ligam a política às identidades.
mock_provider "aws" {}

variables {
  email_name_prefix      = "solar-monitor-dev"
  email_region           = "sa-east-1"
  email_sender_address   = "remetente@exemplo.com"
  email_parameter_prefix = "/solar-monitor/dev"
}

run "remetente_verificado_e_valores_do_backend" {
  command = plan

  assert {
    condition     = aws_sesv2_email_identity.sender.email_identity == "remetente@exemplo.com"
    error_message = "O remetente precisa ser uma identidade do SES."
  }

  assert {
    condition     = output.smtp_host == "email-smtp.sa-east-1.amazonaws.com" && output.smtp_port == 587
    error_message = "MAIL_HOST e MAIL_PORT do SES em São Paulo, com STARTTLS."
  }

  assert {
    condition     = output.mail_from == "Monitoramento de Usinas Solares <remetente@exemplo.com>"
    error_message = "MAIL_FROM no formato Nome <e-mail>."
  }
}

run "destinatario_igual_ao_remetente_nao_duplica" {
  command = plan

  variables {
    email_test_recipients = ["remetente@exemplo.com", "teste@exemplo.com"]
  }

  assert {
    condition     = keys(aws_sesv2_email_identity.test_recipient) == ["teste@exemplo.com"]
    error_message = "O remetente já é verificado: não pode virar uma segunda identidade."
  }

  assert {
    condition     = output.verified_identities == ["remetente@exemplo.com", "teste@exemplo.com"]
    error_message = "A lista de quem precisa confirmar tem o remetente e os destinatários de teste."
  }
}

run "usuario_smtp_so_envia_com_o_remetente" {
  command = apply

  variables {
    email_test_recipients = ["teste@exemplo.com"]
  }

  assert {
    condition     = aws_iam_user.smtp.name == "solar-monitor-dev-ses-smtp"
    error_message = "O usuário SMTP segue o padrão de nome (o script usa esse nome)."
  }

  assert {
    condition     = one(jsondecode(aws_iam_user_policy.smtp_send.policy).Statement).Action == "ses:SendRawEmail"
    error_message = "O usuário SMTP só pode enviar e-mail."
  }

  assert {
    condition     = one(jsondecode(aws_iam_user_policy.smtp_send.policy).Statement).Condition.StringEquals["ses:FromAddress"] == "remetente@exemplo.com"
    error_message = "O envio só pode sair com o remetente configurado."
  }

  assert {
    condition     = toset(one(jsondecode(aws_iam_user_policy.smtp_send.policy).Statement).Resource) == toset([aws_sesv2_email_identity.sender.arn, aws_sesv2_email_identity.test_recipient["teste@exemplo.com"].arn])
    error_message = "No sandbox, a permissão precisa cobrir o remetente e os destinatários de teste."
  }
}

run "parametros_do_smtp_sem_valor_no_estado" {
  command = plan

  assert {
    condition     = toset(keys(aws_ssm_parameter.smtp)) == toset(["MAIL_USER", "MAIL_PASSWORD"])
    error_message = "Precisa dos parâmetros MAIL_USER e MAIL_PASSWORD."
  }

  assert {
    condition     = aws_ssm_parameter.smtp["MAIL_PASSWORD"].name == "/solar-monitor/dev/MAIL_PASSWORD" && aws_ssm_parameter.smtp["MAIL_PASSWORD"].type == "SecureString"
    error_message = "A senha SMTP fica num SecureString em /solar-monitor/dev."
  }

  assert {
    condition     = alltrue([for parameter in aws_ssm_parameter.smtp : parameter.value_wo == null && parameter.value_wo_version == 1])
    error_message = "O valor é write-only: o provisório não vai ao estado, e o real (do script) o Terraform não lê."
  }
}

run "recusa_remetente_invalido" {
  command = plan

  variables {
    email_sender_address = "nao-e-email"
  }

  expect_failures = [var.email_sender_address]
}

run "recusa_prefixo_com_barra_no_fim" {
  command = plan

  variables {
    email_parameter_prefix = "/solar-monitor/dev/"
  }

  expect_failures = [var.email_parameter_prefix]
}
