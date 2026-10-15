# Banco do backend: RDS PostgreSQL numa zona, nas sub-redes privadas, só alcançável pelo security group do backend.
# Senha (decisão do Ericles em 15/10/2026: o RDS não troca a senha, mínimo de manutenção): gerada aqui uma vez e
# gravada no banco e no Parameter Store por atributos write-only, então não fica no estado nem no repositório. Não há
# troca automática, que derrubaria o backend (ele só lê a senha ao subir). Para trocar à mão: aumentar
# database_password_version, aplicar e reiniciar o serviço do backend.

ephemeral "random_password" "master" {
  length = 32
  # O RDS recusa / " @ e espaço na senha do PostgreSQL.
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "main" {
  name        = "${var.database_name_prefix}-db"
  description = "Sub-redes privadas do banco"
  subnet_ids  = var.database_subnet_ids

  tags = var.database_tags
}

resource "aws_db_instance" "main" {
  identifier = "${var.database_name_prefix}-db"

  engine         = "postgres"
  engine_version = var.database_engine_version
  # Versões menores (correções) entram sozinhas na janela de manutenção, de madrugada.
  auto_minor_version_upgrade = true
  instance_class             = var.database_instance_class
  allocated_storage          = var.database_allocated_storage_gb
  storage_type               = "gp3"
  storage_encrypted          = true

  db_name             = var.database_db_name
  username            = var.database_username
  password_wo         = ephemeral.random_password.master.result
  password_wo_version = var.database_password_version
  port                = var.database_port

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.database_security_group_id]
  publicly_accessible    = false
  multi_az               = false

  # Janelas em UTC: 06:00-07:00 é 03:00-04:00 em Brasília, com a usina parada.
  backup_retention_period = var.database_backup_retention_days
  backup_window           = "06:00-07:00"
  maintenance_window      = "sun:07:00-sun:08:00"
  copy_tags_to_snapshot   = true

  # O dev guarda as leituras reais da UFV JAC 03: nada de apagar o banco por engano.
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.database_name_prefix}-db-final"

  # Mudança feita pelo Terraform vale na hora, e não na próxima janela de manutenção.
  apply_immediately = true

  tags = var.database_tags

  lifecycle {
    prevent_destroy = true
  }
}

# A mesma senha, para a task definition do backend ler (DB_PASSWORD, MS-28), como os outros segredos.
resource "aws_ssm_parameter" "password" {
  name             = var.database_password_parameter_name
  description      = "Senha do banco do backend (DB_PASSWORD), gerada pelo Terraform"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.master.result
  value_wo_version = var.database_password_version

  tags = var.database_tags
}
