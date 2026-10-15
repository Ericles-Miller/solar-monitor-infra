output "alb_arn" {
  value       = aws_lb.main.arn
  sensitive   = false
  description = "ARN do ALB"
}

output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  sensitive   = false
  description = "Endereço público do ALB (sem domínio, é por ele que se acessa o dev)"
}

output "alb_zone_id" {
  value       = aws_lb.main.zone_id
  sensitive   = false
  description = "Zona hospedada do ALB, para um registro alias quando houver domínio (MS-30)"
}

output "backend_target_group_arn" {
  value       = aws_lb_target_group.backend.arn
  sensitive   = false
  description = "Target group do backend (serviço ECS da MS-28)"
}

output "frontend_target_group_arn" {
  value       = aws_lb_target_group.frontend.arn
  sensitive   = false
  description = "Target group do frontend (serviço ECS da MS-29)"
}

output "backend_listener_arn" {
  value       = aws_lb_listener.backend.arn
  sensitive   = false
  description = "Listener HTTP do backend"
}

output "frontend_listener_arn" {
  value       = aws_lb_listener.frontend.arn
  sensitive   = false
  description = "Listener HTTP do frontend"
}
