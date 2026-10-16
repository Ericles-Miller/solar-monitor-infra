# Segredos do backend no Parameter Store (SecureString), lidos pela task definition (MS-28). Nenhum vai ao estado:
# - JWT: gerados aqui uma vez, por atributo write-only. Sem troca automática (trocar = aumentar a versão, aplicar e
#   reiniciar o backend; quem estiver logado faz login de novo).
# - Sungrow: nascem com valor provisório write-only; o valor real vem do .env do backend por scripts/backend-secrets.sh.
# A senha do banco (MS-89) e o SMTP (MS-91) têm parâmetros próprios nos módulos database e email.

locals {
  sungrow_names = ["SUNGROW_APPKEY", "SUNGROW_ACCESS_KEY", "SUNGROW_USER_ACCOUNT", "SUNGROW_USER_PASSWORD"]
}

# Os dois segredos precisam ser diferentes (o backend recusa subir com iguais) e ter pelo menos 32 caracteres.
ephemeral "random_password" "jwt_access" {
  length  = 64
  special = false
}

ephemeral "random_password" "jwt_refresh" {
  length  = 64
  special = false
}

resource "aws_ssm_parameter" "jwt_access" {
  name             = "${var.backend_secrets_parameter_prefix}/JWT_ACCESS_SECRET"
  description      = "Segredo do access token (JWT_ACCESS_SECRET), gerado pelo Terraform"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.jwt_access.result
  value_wo_version = var.backend_secrets_jwt_version

  tags = var.backend_secrets_tags
}

resource "aws_ssm_parameter" "jwt_refresh" {
  name             = "${var.backend_secrets_parameter_prefix}/JWT_REFRESH_SECRET"
  description      = "Segredo do refresh token (JWT_REFRESH_SECRET), gerado pelo Terraform"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.jwt_refresh.result
  value_wo_version = var.backend_secrets_jwt_version

  tags = var.backend_secrets_tags
}

resource "aws_ssm_parameter" "sungrow" {
  for_each = toset(local.sungrow_names)

  name             = "${var.backend_secrets_parameter_prefix}/${each.value}"
  description      = "Credencial da Sungrow (${each.value}). Valor gravado por scripts/backend-secrets.sh"
  type             = "SecureString"
  value_wo         = "definir-com-scripts/backend-secrets.sh"
  value_wo_version = 1

  tags = var.backend_secrets_tags
}
