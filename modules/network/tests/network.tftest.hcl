# Roda sem acesso à AWS: terraform -chdir=modules/network init && terraform -chdir=modules/network test
# command = apply com o provider simulado: não cria nada, só gera ids falsos para comparar uma regra com a outra.
mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["sa-east-1a", "sa-east-1b", "sa-east-1c"]
    }
  }
}

variables {
  network_name_prefix        = "solar-monitor-dev"
  network_alb_listener_ports = [80, 8080]
  network_backend_port       = 3333
  network_frontend_port      = 3000
}

run "duas_zonas_com_sub_redes_publicas_e_privadas" {
  command = apply

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2
    error_message = "Precisa de 2 sub-redes públicas e 2 privadas."
  }

  assert {
    condition     = [for subnet in aws_subnet.public : subnet.availability_zone] == ["sa-east-1a", "sa-east-1b"]
    error_message = "As sub-redes públicas precisam ficar em zonas diferentes."
  }

  assert {
    condition     = [for subnet in aws_subnet.private : subnet.availability_zone] == ["sa-east-1a", "sa-east-1b"]
    error_message = "As sub-redes privadas precisam ficar em zonas diferentes (o RDS exige 2)."
  }

  assert {
    condition     = [for subnet in aws_subnet.public : subnet.cidr_block] == ["10.0.0.0/24", "10.0.1.0/24"]
    error_message = "Faixas das sub-redes públicas inesperadas."
  }

  assert {
    condition     = [for subnet in aws_subnet.private : subnet.cidr_block] == ["10.0.10.0/24", "10.0.11.0/24"]
    error_message = "Faixas das sub-redes privadas inesperadas."
  }

  assert {
    condition     = alltrue([for subnet in aws_subnet.public : subnet.map_public_ip_on_launch == false])
    error_message = "A sub-rede não pode dar IP público sozinha: quem pede é o serviço ECS."
  }
}

run "so_as_publicas_tem_rota_para_a_internet" {
  command = apply

  assert {
    condition     = one(aws_route_table.public.route).cidr_block == "0.0.0.0/0" && one(aws_route_table.public.route).gateway_id == aws_internet_gateway.main.id
    error_message = "As públicas saem para a internet pelo internet gateway."
  }

  assert {
    condition     = length(aws_route_table.private.route) == 0
    error_message = "As privadas não podem ter rota para a internet."
  }

  assert {
    condition     = toset([for association in aws_route_table_association.private : association.subnet_id]) == toset(aws_subnet.private[*].id)
    error_message = "Toda sub-rede privada precisa usar a tabela sem internet."
  }
}

run "so_o_alb_recebe_da_internet" {
  command = apply

  assert {
    condition     = keys(aws_vpc_security_group_ingress_rule.alb_from_internet) == ["80", "8080"]
    error_message = "O ALB abre só as portas dos listeners (80 e 8080)."
  }

  assert {
    condition     = alltrue([for rule in aws_vpc_security_group_ingress_rule.alb_from_internet : rule.cidr_ipv4 == "0.0.0.0/0" && rule.security_group_id == aws_security_group.alb.id])
    error_message = "As regras da internet precisam ser do security group do ALB."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.backend_from_alb.referenced_security_group_id == aws_security_group.alb.id && aws_vpc_security_group_ingress_rule.backend_from_alb.from_port == 3333
    error_message = "O backend só aceita o ALB, na porta 3333."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.frontend_from_alb.referenced_security_group_id == aws_security_group.alb.id && aws_vpc_security_group_ingress_rule.frontend_from_alb.from_port == 3000
    error_message = "O frontend só aceita o ALB, na porta 3000."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.database_from_backend.referenced_security_group_id == aws_security_group.backend.id && aws_vpc_security_group_ingress_rule.database_from_backend.from_port == 5432
    error_message = "O banco só aceita o backend, na porta 5432."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.alb_to_backend.referenced_security_group_id == aws_security_group.backend.id && aws_vpc_security_group_egress_rule.alb_to_frontend.referenced_security_group_id == aws_security_group.frontend.id
    error_message = "O ALB só sai para as tarefas."
  }
}

run "recusa_cidr_invalido" {
  command = plan

  variables {
    network_vpc_cidr = "nao-e-cidr"
  }

  expect_failures = [var.network_vpc_cidr]
}

run "recusa_cidr_pequeno_demais" {
  command = plan

  variables {
    network_vpc_cidr = "10.0.0.0/24"
  }

  expect_failures = [var.network_vpc_cidr]
}

run "recusa_uma_zona_so" {
  command = plan

  variables {
    network_az_count = 1
  }

  expect_failures = [var.network_az_count]
}
