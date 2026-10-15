# Um ALB para o backend e o frontend. Sem domínio, os dois saem por HTTP em portas diferentes; a MS-30 troca por
# HTTPS na 443 com roteamento por host. Até os serviços ECS existirem (MS-28 e MS-29), o ALB responde 503.

resource "aws_lb" "main" {
  name               = "${var.alb_name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.alb_subnet_ids

  # Descarta cabeçalhos HTTP malformados em vez de repassá-los às tarefas.
  drop_invalid_header_fields = true

  tags = var.alb_tags
}

# Alvos do tipo ip: é o que o Fargate (rede awsvpc) registra.
resource "aws_lb_target_group" "backend" {
  name        = "${var.alb_name_prefix}-api"
  port        = var.alb_backend_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.alb_vpc_id

  # O backend tem uma tarefa só e o deploy a derruba antes de subir a nova: esperar 5 min (padrão) só atrasa o deploy.
  deregistration_delay = var.alb_deregistration_delay_seconds

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = var.alb_tags
}

resource "aws_lb_target_group" "frontend" {
  name        = "${var.alb_name_prefix}-web"
  port        = var.alb_frontend_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.alb_vpc_id

  deregistration_delay = var.alb_deregistration_delay_seconds

  # /login é pública e responde 200 sem sessão.
  health_check {
    path                = "/login"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = var.alb_tags
}

resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.alb_frontend_listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  tags = var.alb_tags
}

resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.alb_backend_listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  tags = var.alb_tags
}
