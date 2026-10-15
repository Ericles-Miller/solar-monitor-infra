# Roda sem acesso à AWS: terraform -chdir=modules/avatars init && terraform -chdir=modules/avatars test
mock_provider "aws" {}

variables {
  avatars_bucket_name = "solar-monitor-dev-avatars-123456789012"
  avatars_region      = "sa-east-1"
}

run "so_os_avatares_sao_publicos" {
  command = plan

  assert {
    condition     = one([for statement in jsondecode(aws_s3_bucket_policy.avatars.policy).Statement : statement if statement.Effect == "Allow"]).Resource == "arn:aws:s3:::solar-monitor-dev-avatars-123456789012/avatars/*"
    error_message = "A leitura pública vale só para avatars/*."
  }

  assert {
    condition     = one([for statement in jsondecode(aws_s3_bucket_policy.avatars.policy).Statement : statement if statement.Effect == "Allow"]).Action == "s3:GetObject"
    error_message = "O público só pode ler (s3:GetObject)."
  }

  assert {
    condition     = one([for statement in jsondecode(aws_s3_bucket_policy.avatars.policy).Statement : statement if statement.Effect == "Deny"]).Condition.Bool["aws:SecureTransport"] == "false"
    error_message = "Acesso sem HTTPS precisa ser recusado."
  }
}

run "acl_publica_continua_bloqueada" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.avatars.block_public_acls && aws_s3_bucket_public_access_block.avatars.ignore_public_acls
    error_message = "ACL pública precisa continuar bloqueada."
  }

  assert {
    condition     = !aws_s3_bucket_public_access_block.avatars.block_public_policy && !aws_s3_bucket_public_access_block.avatars.restrict_public_buckets
    error_message = "A policy pública dos avatares precisa ser permitida."
  }

  assert {
    condition     = one(aws_s3_bucket_ownership_controls.avatars.rule).object_ownership == "BucketOwnerEnforced"
    error_message = "As ACLs ficam desligadas (BucketOwnerEnforced)."
  }
}

run "criptografado_e_sem_versoes" {
  command = plan

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.avatars.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "O bucket precisa ser criptografado (SSE-S3)."
  }

  assert {
    condition     = one(aws_s3_bucket_versioning.avatars.versioning_configuration).status == "Disabled"
    error_message = "Sem versões: o avatar apagado não pode ficar guardado."
  }
}

run "entrega_o_endereco_publico_do_backend" {
  command = plan

  assert {
    condition     = output.public_url == "https://solar-monitor-dev-avatars-123456789012.s3.sa-east-1.amazonaws.com"
    error_message = "S3_PUBLIC_URL é https://<bucket>.s3.<região>.amazonaws.com, sem barra no final."
  }

  assert {
    condition     = output.public_objects_arn == "arn:aws:s3:::solar-monitor-dev-avatars-123456789012/avatars/*"
    error_message = "A escrita do backend (MS-28) vale para avatars/*."
  }
}

run "recusa_nome_de_bucket_invalido" {
  command = plan

  variables {
    avatars_bucket_name = "Solar_Monitor"
  }

  expect_failures = [var.avatars_bucket_name]
}

run "recusa_prefixo_sem_barra" {
  command = plan

  variables {
    avatars_public_prefix = "avatars"
  }

  expect_failures = [var.avatars_public_prefix]
}
