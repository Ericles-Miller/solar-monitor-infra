# A conta vem do perfil da AWS CLI em AWS_PROFILE (ver README): nada de credencial no código.
provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}
