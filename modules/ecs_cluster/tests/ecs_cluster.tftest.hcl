# Roda sem acesso à AWS: terraform -chdir=modules/ecs_cluster init && terraform -chdir=modules/ecs_cluster test
mock_provider "aws" {}

variables {
  ecs_cluster_name = "solar-monitor-dev"
}

run "cluster_fargate_sem_container_insights" {
  command = plan

  assert {
    condition     = aws_ecs_cluster.main.name == "solar-monitor-dev"
    error_message = "O cluster segue o padrão de nome."
  }

  assert {
    condition     = one(aws_ecs_cluster.main.setting).value == "disabled"
    error_message = "Container Insights fica desligado no dev (é cobrado)."
  }

  assert {
    condition     = aws_ecs_cluster_capacity_providers.main.capacity_providers == toset(["FARGATE"])
    error_message = "Só Fargate comum: o Spot pode derrubar a única tarefa do backend."
  }
}

run "um_grupo_de_log_por_servico_com_14_dias" {
  command = plan

  assert {
    condition     = toset([for group in aws_cloudwatch_log_group.service : group.name]) == toset(["/ecs/solar-monitor-dev/api", "/ecs/solar-monitor-dev/web"])
    error_message = "Precisa de um grupo de log para o backend (api) e outro para o frontend (web)."
  }

  assert {
    condition     = alltrue([for group in aws_cloudwatch_log_group.service : group.retention_in_days == 14])
    error_message = "Os logs ficam 14 dias."
  }
}

run "recusa_retencao_que_o_cloudwatch_nao_aceita" {
  command = plan

  variables {
    ecs_cluster_log_retention_days = 10
  }

  expect_failures = [var.ecs_cluster_log_retention_days]
}
