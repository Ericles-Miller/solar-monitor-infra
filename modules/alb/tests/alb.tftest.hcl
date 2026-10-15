# Roda sem acesso à AWS: terraform -chdir=modules/alb init && terraform -chdir=modules/alb test
# command = apply com o provider simulado: não cria nada; os ARNs falsos ligam listener e target group.
mock_provider "aws" {}

variables {
  alb_name_prefix            = "solar-monitor-dev"
  alb_vpc_id                 = "vpc-123"
  alb_subnet_ids             = ["subnet-a", "subnet-b"]
  alb_security_group_id      = "sg-alb"
  alb_backend_port           = 3333
  alb_frontend_port          = 3000
  alb_frontend_listener_port = 80
  alb_backend_listener_port  = 8080
}

run "alb_publico_nas_sub_redes_publicas" {
  command = plan

  assert {
    condition     = aws_lb.main.name == "solar-monitor-dev-alb" && aws_lb.main.internal == false
    error_message = "O ALB precisa ser público e seguir o padrão de nome."
  }

  assert {
    condition     = toset(aws_lb.main.subnets) == toset(["subnet-a", "subnet-b"]) && toset(aws_lb.main.security_groups) == toset(["sg-alb"])
    error_message = "O ALB precisa das sub-redes e do security group recebidos."
  }

  assert {
    condition     = aws_lb.main.drop_invalid_header_fields == true
    error_message = "O ALB precisa descartar cabeçalhos inválidos."
  }
}

run "target_groups_do_tipo_ip_com_health_check" {
  command = plan

  assert {
    condition     = aws_lb_target_group.backend.target_type == "ip" && aws_lb_target_group.frontend.target_type == "ip"
    error_message = "Fargate registra por IP: os target groups precisam ser do tipo ip."
  }

  assert {
    condition     = aws_lb_target_group.backend.port == 3333 && one(aws_lb_target_group.backend.health_check).path == "/health"
    error_message = "O backend responde na 3333 e o health check é GET /health."
  }

  assert {
    condition     = aws_lb_target_group.frontend.port == 3000 && one(aws_lb_target_group.frontend.health_check).path == "/login"
    error_message = "O frontend responde na 3000 e o health check é GET /login."
  }

  assert {
    condition     = aws_lb_target_group.backend.deregistration_delay == "30"
    error_message = "A espera para tirar uma tarefa do ar precisa ser curta (30 s)."
  }
}

run "porta_80_vai_para_o_frontend_e_8080_para_o_backend" {
  command = apply

  # O provider valida o formato dos ARNs: cada recurso ganha um ARN falso, diferente do outro target group.
  override_resource {
    target = aws_lb.main
    values = { arn = "arn:aws:elasticloadbalancing:sa-east-1:123456789012:loadbalancer/app/solar-monitor-dev-alb/1" }
  }

  override_resource {
    target = aws_lb_target_group.backend
    values = { arn = "arn:aws:elasticloadbalancing:sa-east-1:123456789012:targetgroup/solar-monitor-dev-api/2" }
  }

  override_resource {
    target = aws_lb_target_group.frontend
    values = { arn = "arn:aws:elasticloadbalancing:sa-east-1:123456789012:targetgroup/solar-monitor-dev-web/3" }
  }

  assert {
    condition     = aws_lb_listener.frontend.port == 80 && one(aws_lb_listener.frontend.default_action).target_group_arn == aws_lb_target_group.frontend.arn
    error_message = "A porta 80 precisa encaminhar para o frontend."
  }

  assert {
    condition     = aws_lb_listener.backend.port == 8080 && one(aws_lb_listener.backend.default_action).target_group_arn == aws_lb_target_group.backend.arn
    error_message = "A porta 8080 precisa encaminhar para o backend."
  }

  assert {
    condition     = aws_lb_listener.frontend.protocol == "HTTP" && aws_lb_listener.backend.protocol == "HTTP"
    error_message = "Sem domínio, os listeners são HTTP (a MS-30 troca por HTTPS)."
  }
}

run "recusa_uma_sub_rede_so" {
  command = plan

  variables {
    alb_subnet_ids = ["subnet-a"]
  }

  expect_failures = [var.alb_subnet_ids]
}

run "recusa_prefixo_longo_demais" {
  command = plan

  variables {
    alb_name_prefix = "solar-monitor-ambiente-de-testes"
  }

  expect_failures = [var.alb_name_prefix]
}
