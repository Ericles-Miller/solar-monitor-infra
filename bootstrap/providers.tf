# Sem backend remoto: este diretório cria o bucket do estado, então o próprio estado dele fica local.
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.68.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project    = "solar-monitor"
      ManagedBy  = "terraform"
      Repository = "solar-monitor-infra"
    }
  }
}
