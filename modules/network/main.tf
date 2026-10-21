# Rede do ambiente: VPC em várias zonas, sub-redes públicas (ALB e tarefas ECS) e privadas (RDS), sem NAT Gateway.
# Sem NAT, as tarefas ECS saem para a internet pelo IP público delas; quem protege é o security group, que só aceita
# tráfego vindo do ALB.

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, var.network_az_count)
}

resource "aws_vpc" "main" {
  cidr_block           = var.network_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.network_tags, { Name = "${var.network_name_prefix}-vpc" })
}

# Fecha o security group padrão da VPC (sem regras): recurso que cair nele por engano fica sem acesso.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.network_tags, { Name = "${var.network_name_prefix}-default-fechado" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.network_tags, { Name = "${var.network_name_prefix}-igw" })
}

# Públicas: 10.0.0.0/24, 10.0.1.0/24... O IP público das tarefas é pedido pelo serviço ECS (MS-28), não pela sub-rede.
resource "aws_subnet" "public" {
  count = var.network_az_count

  vpc_id                  = aws_vpc.main.id
  availability_zone       = local.availability_zones[count.index]
  cidr_block              = cidrsubnet(var.network_vpc_cidr, 8, count.index)
  map_public_ip_on_launch = false

  tags = merge(var.network_tags, {
    Name = "${var.network_name_prefix}-publica-${local.availability_zones[count.index]}"
    Tier = "public"
  })
}

# Privadas: 10.0.10.0/24, 10.0.11.0/24... Sem rota para a internet. O RDS pede sub-redes em 2 zonas (MS-89).
resource "aws_subnet" "private" {
  count = var.network_az_count

  vpc_id            = aws_vpc.main.id
  availability_zone = local.availability_zones[count.index]
  cidr_block        = cidrsubnet(var.network_vpc_cidr, 8, 10 + count.index)

  tags = merge(var.network_tags, {
    Name = "${var.network_name_prefix}-privada-${local.availability_zones[count.index]}"
    Tier = "private"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.network_tags, { Name = "${var.network_name_prefix}-rotas-publicas" })
}

resource "aws_route_table_association" "public" {
  count = var.network_az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Só a rota local da VPC: nada nas sub-redes privadas fala com a internet.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.network_tags, { Name = "${var.network_name_prefix}-rotas-privadas" })
}

resource "aws_route_table_association" "private" {
  count = var.network_az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# --- Security groups -------------------------------------------------------------------------------------------------
# As regras ficam em recursos próprios (aws_vpc_security_group_*_rule), não inline, para um grupo poder citar o outro.

resource "aws_security_group" "alb" {
  name        = "${var.network_name_prefix}-alb"
  description = "ALB: HTTP da internet"
  vpc_id      = aws_vpc.main.id

  tags = merge(var.network_tags, { Name = "${var.network_name_prefix}-alb" })
}

resource "aws_security_group" "backend" {
  name        = "${var.network_name_prefix}-backend"
  description = "Tarefas do backend: so o ALB entra"
  vpc_id      = aws_vpc.main.id

  tags = merge(var.network_tags, { Name = "${var.network_name_prefix}-backend" })
}

resource "aws_security_group" "frontend" {
  name        = "${var.network_name_prefix}-frontend"
  description = "Tarefas do frontend: so o ALB entra"
  vpc_id      = aws_vpc.main.id

  tags = merge(var.network_tags, { Name = "${var.network_name_prefix}-frontend" })
}

# Sem regra de saída: o banco só responde a conexões que recebe.
resource "aws_security_group" "database" {
  name        = "${var.network_name_prefix}-database"
  description = "RDS: so o backend entra"
  vpc_id      = aws_vpc.main.id

  tags = merge(var.network_tags, { Name = "${var.network_name_prefix}-database" })
}

# ALB: entra HTTP da internet nas portas dos listeners (a do backend sai com o domínio, MS-30).
resource "aws_vpc_security_group_ingress_rule" "alb_from_internet" {
  for_each = toset([for port in var.network_alb_listener_ports : tostring(port)])

  security_group_id = aws_security_group.alb.id
  description       = "HTTP da internet na porta ${each.value}"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
}

# ALB: só sai para as tarefas, nas portas delas (tráfego e health check).
resource "aws_vpc_security_group_egress_rule" "alb_to_backend" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Para o backend"
  referenced_security_group_id = aws_security_group.backend.id
  ip_protocol                  = "tcp"
  from_port                    = var.network_backend_port
  to_port                      = var.network_backend_port
}

resource "aws_vpc_security_group_egress_rule" "alb_to_frontend" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Para o frontend"
  referenced_security_group_id = aws_security_group.frontend.id
  ip_protocol                  = "tcp"
  from_port                    = var.network_frontend_port
  to_port                      = var.network_frontend_port
}

resource "aws_vpc_security_group_ingress_rule" "backend_from_alb" {
  security_group_id            = aws_security_group.backend.id
  description                  = "Do ALB"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.network_backend_port
  to_port                      = var.network_backend_port
}

# Backend sai para qualquer lugar: Sungrow, SMTP do Gmail, ECR, S3, Parameter Store e o RDS.
resource "aws_vpc_security_group_egress_rule" "backend_to_anywhere" {
  security_group_id = aws_security_group.backend.id
  description       = "Saida livre (Sungrow, SMTP, ECR, S3, SSM, RDS)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "frontend_from_alb" {
  security_group_id            = aws_security_group.frontend.id
  description                  = "Do ALB"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.network_frontend_port
  to_port                      = var.network_frontend_port
}

# Frontend sai para baixar a imagem (ECR) e falar com o backend.
resource "aws_vpc_security_group_egress_rule" "frontend_to_anywhere" {
  security_group_id = aws_security_group.frontend.id
  description       = "Saida livre (ECR, backend)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "database_from_backend" {
  security_group_id            = aws_security_group.database.id
  description                  = "Do backend"
  referenced_security_group_id = aws_security_group.backend.id
  ip_protocol                  = "tcp"
  from_port                    = var.network_database_port
  to_port                      = var.network_database_port
}
