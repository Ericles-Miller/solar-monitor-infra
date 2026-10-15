# Roda sem acesso à AWS: terraform -chdir=modules/database init && terraform -chdir=modules/database test
# Só o provider da AWS é simulado; o random roda de verdade (é local e não precisa de credencial).
mock_provider "aws" {}

variables {
  database_name_prefix             = "solar-monitor-dev"
  database_subnet_ids              = ["subnet-a", "subnet-b"]
  database_security_group_id       = "sg-database"
  database_password_parameter_name = "/solar-monitor/dev/DB_PASSWORD"
}

run "postgres_15_pequeno_e_criptografado" {
  command = plan

  assert {
    condition     = aws_db_instance.main.engine == "postgres" && aws_db_instance.main.engine_version == "15"
    error_message = "PostgreSQL 15, a mesma versão principal do docker-compose."
  }

  assert {
    condition     = aws_db_instance.main.instance_class == "db.t4g.micro" && aws_db_instance.main.allocated_storage == 20 && aws_db_instance.main.storage_type == "gp3"
    error_message = "db.t4g.micro com 20 GB gp3 (doc 09)."
  }

  assert {
    condition     = aws_db_instance.main.storage_encrypted && aws_db_instance.main.auto_minor_version_upgrade
    error_message = "O disco precisa ser criptografado, e as versões menores entram sozinhas."
  }

  assert {
    condition     = aws_db_instance.main.db_name == "solar_monitor" && aws_db_instance.main.username == "solar_monitor"
    error_message = "Banco e usuário solar_monitor (DB_NAME e DB_USERNAME do backend)."
  }
}

run "so_na_rede_privada_e_so_pelo_backend" {
  command = plan

  assert {
    condition     = aws_db_instance.main.publicly_accessible == false && aws_db_instance.main.multi_az == false
    error_message = "Sem acesso público e numa zona só."
  }

  assert {
    condition     = toset(aws_db_subnet_group.main.subnet_ids) == toset(["subnet-a", "subnet-b"])
    error_message = "O banco fica nas sub-redes privadas recebidas."
  }

  assert {
    condition     = toset(aws_db_instance.main.vpc_security_group_ids) == toset(["sg-database"])
    error_message = "Só o security group do banco (que só aceita o backend)."
  }
}

run "dados_reais_protegidos" {
  command = plan

  assert {
    condition     = aws_db_instance.main.deletion_protection && aws_db_instance.main.skip_final_snapshot == false
    error_message = "Proteção contra exclusão e snapshot final ligados (leituras reais da UFV JAC 03)."
  }

  assert {
    condition     = aws_db_instance.main.final_snapshot_identifier == "solar-monitor-dev-db-final"
    error_message = "O snapshot final precisa de nome."
  }

  assert {
    condition     = aws_db_instance.main.backup_retention_period == 7 && aws_db_instance.main.backup_window == "06:00-07:00"
    error_message = "Backup de 7 dias, de madrugada no horário de Brasília."
  }
}

run "senha_fora_do_estado_e_sem_troca_automatica" {
  command = plan

  assert {
    condition     = aws_db_instance.main.password == null && aws_db_instance.main.password_wo == null
    error_message = "A senha não pode aparecer no plano nem no estado (só write-only)."
  }

  assert {
    condition     = aws_db_instance.main.password_wo_version == 1 && aws_ssm_parameter.password.value_wo_version == 1
    error_message = "Banco e parâmetro recebem a senha na mesma versão."
  }

  assert {
    condition     = aws_ssm_parameter.password.type == "SecureString" && aws_ssm_parameter.password.name == "/solar-monitor/dev/DB_PASSWORD" && aws_ssm_parameter.password.value_wo == null
    error_message = "A senha fica num SecureString, sem valor no estado."
  }
}

run "nova_versao_troca_a_senha_nos_dois" {
  command = plan

  variables {
    database_password_version = 2
  }

  assert {
    condition     = aws_db_instance.main.password_wo_version == 2 && aws_ssm_parameter.password.value_wo_version == 2
    error_message = "Trocar a versão precisa trocar a senha no banco e no parâmetro juntos."
  }
}

run "recusa_uma_sub_rede_so" {
  command = plan

  variables {
    database_subnet_ids = ["subnet-a"]
  }

  expect_failures = [var.database_subnet_ids]
}

run "recusa_versao_de_senha_invalida" {
  command = plan

  variables {
    database_password_version = 0
  }

  expect_failures = [var.database_password_version]
}

run "recusa_backup_desligado" {
  command = plan

  variables {
    database_backup_retention_days = 0
  }

  expect_failures = [var.database_backup_retention_days]
}

run "recusa_parametro_sem_barra" {
  command = plan

  variables {
    database_password_parameter_name = "solar-monitor/dev/DB_PASSWORD"
  }

  expect_failures = [var.database_password_parameter_name]
}
