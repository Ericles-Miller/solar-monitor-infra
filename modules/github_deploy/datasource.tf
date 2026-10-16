# O provedor OIDC do GitHub é um só por conta e já existe (criado por outro projeto): reaproveitado, não criado aqui.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}
