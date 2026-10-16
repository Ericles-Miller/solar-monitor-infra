# Papel que o GitHub Actions assume (OIDC, sem chave guardada no GitHub) para publicar um serviço no ECS (MS-94):
# enviar a imagem ao ECR, registrar a revisão nova da task definition e atualizar o serviço. Só as branches liberadas
# do repositório (hoje, a develop) conseguem assumir. O ARN vai no secret ROLE_ASSUME do repositório.

locals {
  subjects = [for branch in var.github_deploy_branches : "repo:${var.github_deploy_repository}:ref:refs/heads/${branch}"]
}

resource "aws_iam_role" "deploy" {
  name        = var.github_deploy_name
  description = "Deploy do ${var.github_deploy_repository} pelo GitHub Actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = local.subjects
          }
        }
      },
    ]
  })

  tags = var.github_deploy_tags
}

resource "aws_iam_role_policy" "deploy" {
  name = "publicar-no-ecs"
  role = aws_iam_role.deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "LoginNoEcr"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "EnviarImagem"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = var.github_deploy_ecr_repository_arn
      },
      {
        # Estas duas ações do ECS não aceitam recurso específico.
        Sid      = "RevisaoDaTaskDefinition"
        Effect   = "Allow"
        Action   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
        Resource = "*"
      },
      {
        Sid      = "AtualizarOServico"
        Effect   = "Allow"
        Action   = ["ecs:DescribeServices", "ecs:UpdateService"]
        Resource = var.github_deploy_ecs_service_arn
      },
      {
        Sid       = "PassarOsPapeisDaTarefa"
        Effect    = "Allow"
        Action    = "iam:PassRole"
        Resource  = var.github_deploy_pass_role_arns
        Condition = { StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" } }
      },
    ]
  })
}
