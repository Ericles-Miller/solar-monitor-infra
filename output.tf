output "account_id" {
  value       = data.aws_caller_identity.current.account_id
  sensitive   = false
  description = "Conta da AWS onde o ambiente foi criado"
}

output "region" {
  value       = var.aws_region
  sensitive   = false
  description = "Região do ambiente"
}

output "budget_name" {
  value       = module.budget.budget_name
  sensitive   = false
  description = "Nome do orçamento com o alerta de custo"
}

output "frontend_url" {
  value       = "http://${module.alb.alb_dns_name}"
  sensitive   = false
  description = "Endereço do frontend, enquanto não há domínio"
}

output "backend_url" {
  value       = "http://${module.alb.alb_dns_name}:${var.backend_listener_port}"
  sensitive   = false
  description = "Endereço do backend, enquanto não há domínio (NEXT_PUBLIC_API_URL do frontend)"
}

output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  sensitive   = false
  description = "DNS do ALB"
}

output "vpc_id" {
  value       = module.network.vpc_id
  sensitive   = false
  description = "Id da VPC"
}

output "public_subnet_ids" {
  value       = module.network.public_subnet_ids
  sensitive   = false
  description = "Sub-redes públicas (ALB e tarefas ECS)"
}

output "private_subnet_ids" {
  value       = module.network.private_subnet_ids
  sensitive   = false
  description = "Sub-redes privadas (RDS, MS-89)"
}

output "security_group_ids" {
  value = {
    alb      = module.network.alb_security_group_id
    backend  = module.network.backend_security_group_id
    frontend = module.network.frontend_security_group_id
    database = module.network.database_security_group_id
  }
  sensitive   = false
  description = "Security groups do ALB, das tarefas e do banco"
}

output "ecs_cluster_name" {
  value       = module.ecs_cluster.cluster_name
  sensitive   = false
  description = "Nome do cluster ECS"
}

output "target_group_arns" {
  value = {
    backend  = module.alb.backend_target_group_arn
    frontend = module.alb.frontend_target_group_arn
  }
  sensitive   = false
  description = "Target groups do backend (MS-28) e do frontend (MS-29)"
}

output "log_group_names" {
  value       = module.ecs_cluster.log_group_names
  sensitive   = false
  description = "Grupos de log do CloudWatch por serviço"
}
