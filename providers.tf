terraform {
  # >= 1.10: a trava do estado usa o lockfile nativo do S3 (use_lockfile), sem DynamoDB.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.68.0"
    }
  }

  # Bucket criado pelo bootstrap/. O backend não lê variáveis do Terraform: perfil e região ficam fixos aqui.
  # O perfil é explícito porque a máquina pode ter um perfil "default" de outra conta.
  backend "s3" {
    bucket       = "solar-monitor-tfstate-779257801295"
    key          = "dev/terraform.tfstate"
    region       = "sa-east-1"
    profile      = "ericles-dev"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = local.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "solar-monitor-infra"
    }
  }
}
