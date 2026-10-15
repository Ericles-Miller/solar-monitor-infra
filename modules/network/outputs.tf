output "vpc_id" {
  value       = aws_vpc.main.id
  sensitive   = false
  description = "Id da VPC"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  sensitive   = false
  description = "Sub-redes públicas (ALB e tarefas ECS), uma por zona"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  sensitive   = false
  description = "Sub-redes privadas (RDS), uma por zona"
}

output "availability_zones" {
  value       = local.availability_zones
  sensitive   = false
  description = "Zonas usadas, na ordem das sub-redes"
}

output "alb_security_group_id" {
  value       = aws_security_group.alb.id
  sensitive   = false
  description = "Security group do ALB"
}

output "backend_security_group_id" {
  value       = aws_security_group.backend.id
  sensitive   = false
  description = "Security group das tarefas do backend"
}

output "frontend_security_group_id" {
  value       = aws_security_group.frontend.id
  sensitive   = false
  description = "Security group das tarefas do frontend"
}

output "database_security_group_id" {
  value       = aws_security_group.database.id
  sensitive   = false
  description = "Security group do RDS"
}
