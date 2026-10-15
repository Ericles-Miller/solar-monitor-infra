# E-mail do backend pelo SES, por SMTP (o backend usa Nodemailer: só precisa de host, porta, usuário e senha).
# Sem domínio, o remetente é um endereço verificado (a AWS manda um link de confirmação para ele). No sandbox o SES só
# entrega para endereços verificados: o remetente e os destinatários de teste. A MS-30 troca por domínio com DKIM.

locals {
  # O remetente já é uma identidade verificada; repetir o mesmo endereço criaria uma identidade duplicada.
  test_recipients = setsubtract(toset(var.email_test_recipients), [var.email_sender_address])

  identity_arns = concat(
    [aws_sesv2_email_identity.sender.arn],
    [for identity in aws_sesv2_email_identity.test_recipient : identity.arn],
  )
}

resource "aws_sesv2_email_identity" "sender" {
  email_identity = var.email_sender_address

  tags = var.email_tags
}

resource "aws_sesv2_email_identity" "test_recipient" {
  for_each = local.test_recipients

  email_identity = each.value

  tags = var.email_tags
}

# Usuário só para o SMTP. A chave dele é gerada fora do Terraform (scripts/ses-smtp-credentials.sh), para não ir ao estado.
resource "aws_iam_user" "smtp" {
  name = "${var.email_name_prefix}-ses-smtp"

  tags = var.email_tags
}

# Só envia, e só com o remetente configurado. No sandbox o SES também confere a permissão nos destinatários
# verificados, por isso as identidades de teste entram no Resource.
resource "aws_iam_user_policy" "smtp_send" {
  name = "enviar-email-pelo-ses"
  user = aws_iam_user.smtp.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "SoEnviarComORemetente"
        Effect    = "Allow"
        Action    = "ses:SendRawEmail"
        Resource  = local.identity_arns
        Condition = { StringEquals = { "ses:FromAddress" = var.email_sender_address } }
      },
    ]
  })
}

# MAIL_USER e MAIL_PASSWORD do backend (MS-28). Nascem com um valor provisório write-only, que não vai ao estado; o
# valor real é gravado pelo script e o Terraform não o lê de volta (com `value`, um SecureString iria ao estado em
# texto puro).
resource "aws_ssm_parameter" "smtp" {
  for_each = toset(["MAIL_USER", "MAIL_PASSWORD"])

  name             = "${var.email_parameter_prefix}/${each.value}"
  description      = "SMTP do SES (${each.value}). Valor gravado por scripts/ses-smtp-credentials.sh"
  type             = "SecureString"
  value_wo         = "definir-com-scripts/ses-smtp-credentials.sh"
  value_wo_version = 1

  tags = var.email_tags
}
