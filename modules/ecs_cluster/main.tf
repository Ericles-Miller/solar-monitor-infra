# Cluster Fargate onde rodam o backend (MS-28) e o frontend (MS-29), e os grupos de log dos dois.

resource "aws_ecs_cluster" "main" {
  name = var.ecs_cluster_name

  # Container Insights cobra por métrica: desligado no dev, os logs bastam.
  setting {
    name  = "containerInsights"
    value = var.ecs_cluster_container_insights ? "enabled" : "disabled"
  }

  tags = var.ecs_cluster_tags
}

# Só Fargate comum: o backend tem uma tarefa só (o coletor roda no processo) e o Spot pode derrubá-la a qualquer hora.
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

resource "aws_cloudwatch_log_group" "service" {
  for_each = toset(var.ecs_cluster_log_services)

  name              = "/ecs/${var.ecs_cluster_name}/${each.value}"
  retention_in_days = var.ecs_cluster_log_retention_days

  tags = var.ecs_cluster_tags
}
