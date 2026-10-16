# Roda sem acesso à AWS: terraform -chdir=modules/ecr init && terraform -chdir=modules/ecr test
mock_provider "aws" {}

variables {
  ecr_repository_name = "solar-monitor-api"
}

run "tag_fixa_e_scan_ao_enviar" {
  command = plan

  assert {
    condition     = aws_ecr_repository.main.image_tag_mutability == "IMMUTABLE"
    error_message = "A tag não pode ser sobrescrita: cada deploy aponta para uma imagem exata."
  }

  assert {
    condition     = one(aws_ecr_repository.main.image_scanning_configuration).scan_on_push
    error_message = "A imagem é verificada ao ser enviada."
  }
}

run "guarda_so_as_ultimas_10" {
  command = plan

  assert {
    condition     = one(jsondecode(aws_ecr_lifecycle_policy.main.policy).rules).selection.countNumber == 10
    error_message = "O repositório guarda as 10 imagens mais recentes."
  }
}

run "recusa_nome_invalido" {
  command = plan

  variables {
    ecr_repository_name = "Solar_Monitor"
  }

  expect_failures = [var.ecr_repository_name]
}

run "recusa_guardar_uma_so" {
  command = plan

  variables {
    ecr_keep_images = 1
  }

  expect_failures = [var.ecr_keep_images]
}
