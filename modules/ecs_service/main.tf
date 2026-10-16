# Um serviço ECS Fargate atrás do ALB: papéis IAM, task definition com um contêiner e o serviço. Usado pelo backend
# (MS-28) e pelo frontend (MS-29). Segredos vêm do Parameter Store pelo bloco `secrets` (nunca como variável comum).

locals {
  # Contêineres do ECS não usam o HEALTHCHECK do Dockerfile: o equivalente vai na task definition. As duas imagens
  # (Nest e Next) têm Node, então o teste é um fetch local.
  health_check = var.ecs_service_health_check_path == null ? null : {
    command = [
      "CMD-SHELL",
      "node -e \"fetch('http://127.0.0.1:${var.ecs_service_container_port}${var.ecs_service_health_check_path}').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))\"",
    ]
    interval    = 30
    timeout     = 5
    retries     = 3
    startPeriod = 60
  }

  container = merge(
    {
      name         = var.ecs_service_container_name
      image        = var.ecs_service_image
      essential    = true
      portMappings = [{ containerPort = var.ecs_service_container_port, protocol = "tcp" }]
      environment  = [for name, value in var.ecs_service_environment : { name = name, value = value }]
      secrets      = [for name, arn in var.ecs_service_secrets : { name = name, valueFrom = arn }]
      # Processo init para o ECS Exec e para o sinal de parada chegar ao Node.
      linuxParameters = { initProcessEnabled = true }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.ecs_service_log_group_name
          "awslogs-region"        = var.ecs_service_region
          "awslogs-stream-prefix" = var.ecs_service_container_name
        }
      }
    },
    local.health_check == null ? {} : { healthCheck = local.health_check },
  )

  ecs_tasks_trust = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      },
    ]
  })
}

# --- Papel de execução: o ECS usa para puxar a imagem, escrever os logs e ler os segredos -----------------------------

resource "aws_iam_role" "execution" {
  name               = "${var.ecs_service_name}-execucao"
  assume_role_policy = local.ecs_tasks_trust

  tags = var.ecs_service_tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Só os parâmetros deste serviço. A chave padrão do Parameter Store (aws/ssm) não pede kms:Decrypt à parte.
resource "aws_iam_role_policy" "execution_secrets" {
  count = length(var.ecs_service_secrets) > 0 ? 1 : 0

  name = "ler-segredos"
  role = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:GetParameters"
        Resource = sort(distinct(values(var.ecs_service_secrets)))
      },
    ]
  })
}

# --- Papel da tarefa: o que o código do serviço pode fazer na AWS -------------------------------------------------

resource "aws_iam_role" "task" {
  name               = "${var.ecs_service_name}-tarefa"
  assume_role_policy = local.ecs_tasks_trust

  tags = var.ecs_service_tags
}

resource "aws_iam_role_policy" "task" {
  count = var.ecs_service_task_policy_json == null ? 0 : 1

  name   = "permissoes-do-servico"
  role   = aws_iam_role.task.id
  policy = var.ecs_service_task_policy_json
}

# ECS Exec: abrir um shell na tarefa (ex.: plant:import no backend).
resource "aws_iam_role_policy" "task_exec" {
  count = var.ecs_service_enable_execute_command ? 1 : 0

  name = "ecs-exec"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
        ]
        Resource = "*"
      },
    ]
  })
}

# --- Task definition e serviço -------------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "main" {
  family                   = var.ecs_service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.ecs_service_cpu)
  memory                   = tostring(var.ecs_service_memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.ecs_service_cpu_architecture
  }

  container_definitions = jsonencode([local.container])

  tags = var.ecs_service_tags
}

resource "aws_ecs_service" "main" {
  name            = var.ecs_service_name
  cluster         = var.ecs_service_cluster_arn
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.ecs_service_desired_count

  # Explícito, igual à estratégia padrão do cluster: sem ele o Terraform veria diferença a cada plan.
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }

  # 0% / 100%: a tarefa antiga sai antes de a nova subir, então nunca há duas ao mesmo tempo (o backend tem um coletor
  # dentro do processo). O dev aceita a queda curta durante o deploy.
  deployment_minimum_healthy_percent = var.ecs_service_deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.ecs_service_deployment_maximum_percent

  # Deploy que não fica saudável volta sozinho para a versão anterior.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  enable_execute_command            = var.ecs_service_enable_execute_command
  health_check_grace_period_seconds = var.ecs_service_health_check_grace_period_seconds
  propagate_tags                    = "SERVICE"

  network_configuration {
    subnets          = var.ecs_service_subnet_ids
    security_groups  = var.ecs_service_security_group_ids
    assign_public_ip = var.ecs_service_assign_public_ip
  }

  load_balancer {
    target_group_arn = var.ecs_service_target_group_arn
    container_name   = var.ecs_service_container_name
    container_port   = var.ecs_service_container_port
  }

  tags = var.ecs_service_tags

  # Quem publica versão nova é o CI (MS-94): ele registra uma revisão da task definition com a imagem nova e atualiza o
  # serviço. O Terraform não pode voltar o serviço para a revisão dele. Uma mudança feita aqui na task definition
  # (variável, segredo) vira uma revisão nova que entra no próximo deploy do CI, que parte sempre da revisão mais nova.
  lifecycle {
    ignore_changes = [task_definition]
  }
}
