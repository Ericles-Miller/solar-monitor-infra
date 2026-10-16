# Roda sem acesso à AWS: terraform -chdir=modules/ecs_service init && terraform -chdir=modules/ecs_service test
# command = apply com o provider simulado: não cria nada; os ARNs falsos ligam papéis, task definition e serviço.
mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/papel-falso" }
  }
  mock_resource "aws_ecs_task_definition" {
    defaults = { arn = "arn:aws:ecs:sa-east-1:123456789012:task-definition/solar-monitor-dev-api:1" }
  }
}

variables {
  ecs_service_name               = "solar-monitor-dev-api"
  ecs_service_cluster_arn        = "arn:aws:ecs:sa-east-1:123456789012:cluster/solar-monitor-dev"
  ecs_service_image              = "123456789012.dkr.ecr.sa-east-1.amazonaws.com/solar-monitor-api:abc1234"
  ecs_service_container_name     = "api"
  ecs_service_container_port     = 3333
  ecs_service_cpu                = 512
  ecs_service_memory             = 1024
  ecs_service_log_group_name     = "/ecs/solar-monitor-dev/api"
  ecs_service_region             = "sa-east-1"
  ecs_service_subnet_ids         = ["subnet-a", "subnet-b"]
  ecs_service_security_group_ids = ["sg-backend"]
  ecs_service_target_group_arn   = "arn:aws:elasticloadbalancing:sa-east-1:123456789012:targetgroup/solar-monitor-dev-api/1"
  ecs_service_health_check_path  = "/health"
  ecs_service_environment        = { DB_HOST = "banco.local", TZ = "America/Sao_Paulo" }
  ecs_service_secrets = {
    DB_PASSWORD = "arn:aws:ssm:sa-east-1:123456789012:parameter/solar-monitor/dev/DB_PASSWORD"
    JWT_SECRET  = "arn:aws:ssm:sa-east-1:123456789012:parameter/solar-monitor/dev/JWT_SECRET"
  }
}

run "uma_tarefa_que_nunca_dobra" {
  command = plan

  assert {
    condition     = aws_ecs_service.main.desired_count == 1
    error_message = "O backend roda com 1 tarefa (o coletor fica no processo)."
  }

  assert {
    condition     = aws_ecs_service.main.deployment_minimum_healthy_percent == 0 && aws_ecs_service.main.deployment_maximum_percent == 100
    error_message = "No deploy, a tarefa antiga sai antes da nova: nunca duas ao mesmo tempo."
  }

  assert {
    condition     = one(aws_ecs_service.main.deployment_circuit_breaker).rollback
    error_message = "Deploy que não fica saudável volta sozinho."
  }
}

run "fargate_arm_na_rede_e_no_alb" {
  command = plan

  assert {
    condition     = one(aws_ecs_task_definition.main.runtime_platform).cpu_architecture == "ARM64" && aws_ecs_task_definition.main.cpu == "512" && aws_ecs_task_definition.main.memory == "1024"
    error_message = "0,5 vCPU e 1 GB em ARM64."
  }

  assert {
    condition     = one(aws_ecs_service.main.network_configuration).assign_public_ip && toset(one(aws_ecs_service.main.network_configuration).security_groups) == toset(["sg-backend"])
    error_message = "Sem NAT, a tarefa sai pelo IP público; só o security group recebido."
  }

  assert {
    condition     = one(aws_ecs_service.main.load_balancer).container_name == "api" && one(aws_ecs_service.main.load_balancer).container_port == 3333
    error_message = "O ALB registra o contêiner api na porta 3333."
  }
}

run "segredos_so_pelo_parameter_store" {
  command = plan

  assert {
    condition     = toset([for s in one(jsondecode(aws_ecs_task_definition.main.container_definitions)).secrets : s.name]) == toset(["DB_PASSWORD", "JWT_SECRET"])
    error_message = "Os segredos entram pelo bloco secrets."
  }

  assert {
    condition     = !contains([for e in one(jsondecode(aws_ecs_task_definition.main.container_definitions)).environment : e.name], "DB_PASSWORD")
    error_message = "Segredo nunca entra como variável comum."
  }

  assert {
    condition     = toset(jsondecode(aws_iam_role_policy.execution_secrets[0].policy).Statement[0].Resource) == toset(values(var.ecs_service_secrets))
    error_message = "O papel de execução só lê os parâmetros deste serviço."
  }
}

run "health_check_e_logs_do_conteiner" {
  command = plan

  assert {
    condition     = strcontains(one(jsondecode(aws_ecs_task_definition.main.container_definitions)).healthCheck.command[1], "http://127.0.0.1:3333/health")
    error_message = "O health check do contêiner chama /health na porta do serviço."
  }

  assert {
    condition     = one(jsondecode(aws_ecs_task_definition.main.container_definitions)).logConfiguration.options["awslogs-group"] == "/ecs/solar-monitor-dev/api"
    error_message = "Os logs vão para o grupo da MS-88."
  }
}

run "ecs_exec_so_quando_ligado" {
  command = apply

  variables {
    ecs_service_enable_execute_command = true
    ecs_service_task_policy_json       = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"s3:PutObject\",\"Resource\":\"arn:aws:s3:::bucket/avatars/*\"}]}"
  }

  assert {
    condition     = aws_ecs_service.main.enable_execute_command && length(aws_iam_role_policy.task_exec) == 1
    error_message = "Com o ECS Exec ligado, o papel da tarefa precisa dos canais do Session Manager."
  }

  assert {
    condition     = length(aws_iam_role_policy.task) == 1
    error_message = "A política própria do serviço vai no papel da tarefa."
  }
}

run "sem_segredos_nem_exec_nao_cria_politicas" {
  command = plan

  variables {
    ecs_service_secrets = {}
  }

  assert {
    condition     = length(aws_iam_role_policy.execution_secrets) == 0 && length(aws_iam_role_policy.task_exec) == 0 && length(aws_iam_role_policy.task) == 0
    error_message = "Sem segredos, sem ECS Exec e sem política própria, nenhuma política extra."
  }
}

run "recusa_arquitetura_invalida" {
  command = plan

  variables {
    ecs_service_cpu_architecture = "ARM"
  }

  expect_failures = [var.ecs_service_cpu_architecture]
}

run "recusa_nome_longo_demais" {
  command = plan

  variables {
    ecs_service_name = "solar-monitor-ambiente-de-desenvolvimento-com-nome-longo"
  }

  expect_failures = [var.ecs_service_name]
}
