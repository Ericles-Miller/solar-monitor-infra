# Roda sem acesso à AWS: terraform -chdir=modules/github_deploy init && terraform -chdir=modules/github_deploy test
mock_provider "aws" {
  mock_data "aws_iam_openid_connect_provider" {
    defaults = { arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" }
  }
}

variables {
  github_deploy_name               = "solar-monitor-dev-github-api"
  github_deploy_repository         = "Ericles-Miller/solar-monitor"
  github_deploy_ecr_repository_arn = "arn:aws:ecr:sa-east-1:123456789012:repository/solar-monitor-api"
  github_deploy_ecs_service_arn    = "arn:aws:ecs:sa-east-1:123456789012:service/solar-monitor-dev/solar-monitor-dev-api"
  github_deploy_pass_role_arns = [
    "arn:aws:iam::123456789012:role/solar-monitor-dev-api-execucao",
    "arn:aws:iam::123456789012:role/solar-monitor-dev-api-tarefa",
  ]
}

run "so_a_develop_do_repositorio_assume" {
  command = plan

  assert {
    condition     = one(jsondecode(aws_iam_role.deploy.assume_role_policy).Statement).Condition.StringEquals["token.actions.githubusercontent.com:sub"] == ["repo:Ericles-Miller/solar-monitor:ref:refs/heads/develop"]
    error_message = "Só a develop do repositório pode publicar."
  }

  assert {
    condition     = one(jsondecode(aws_iam_role.deploy.assume_role_policy).Statement).Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com"
    error_message = "Só o token do GitHub para a AWS vale."
  }

  assert {
    condition     = one(jsondecode(aws_iam_role.deploy.assume_role_policy).Statement).Principal.Federated == "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    error_message = "A confiança é no provedor OIDC do GitHub que já existe na conta."
  }
}

run "permissoes_so_do_servico" {
  command = plan

  assert {
    condition     = one([for s in jsondecode(aws_iam_role_policy.deploy.policy).Statement : s if s.Sid == "EnviarImagem"]).Resource == "arn:aws:ecr:sa-east-1:123456789012:repository/solar-monitor-api"
    error_message = "A imagem só pode ir para o repositório do serviço."
  }

  assert {
    condition     = one([for s in jsondecode(aws_iam_role_policy.deploy.policy).Statement : s if s.Sid == "AtualizarOServico"]).Resource == "arn:aws:ecs:sa-east-1:123456789012:service/solar-monitor-dev/solar-monitor-dev-api"
    error_message = "Só este serviço pode ser atualizado."
  }

  assert {
    condition     = one([for s in jsondecode(aws_iam_role_policy.deploy.policy).Statement : s if s.Sid == "PassarOsPapeisDaTarefa"]).Condition.StringEquals["iam:PassedToService"] == "ecs-tasks.amazonaws.com"
    error_message = "Os papéis só podem ser passados ao ECS."
  }

  assert {
    condition     = toset(one([for s in jsondecode(aws_iam_role_policy.deploy.policy).Statement : s if s.Sid == "PassarOsPapeisDaTarefa"]).Resource) == toset(var.github_deploy_pass_role_arns)
    error_message = "Só os dois papéis do serviço."
  }
}

run "recusa_repositorio_mal_escrito" {
  command = plan

  variables {
    github_deploy_repository = "solar-monitor"
  }

  expect_failures = [var.github_deploy_repository]
}

run "recusa_curinga_nas_branches" {
  command = plan

  variables {
    github_deploy_branches = ["*"]
  }

  expect_failures = [var.github_deploy_branches]
}
