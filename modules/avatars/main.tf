# Bucket dos avatares (MS-55): o backend grava em avatars/<userId>/<uuid>.<ext> e o navegador lê direto do S3.
# Leitura pública só do prefixo dos avatares, por bucket policy (sem ACL). A escrita fica no papel da tarefa do
# backend (MS-28), não em usuário com chave.

locals {
  # Montado a partir do nome (conhecido no plan) para a policy e os testes não dependerem de valor calculado na AWS.
  bucket_arn         = "arn:aws:s3:::${aws_s3_bucket.avatars.bucket}"
  public_objects_arn = "${local.bucket_arn}/${var.avatars_public_prefix}*"
}

resource "aws_s3_bucket" "avatars" {
  bucket = var.avatars_bucket_name

  tags = var.avatars_tags
}

# Desliga as ACLs: o dono do bucket é dono de todo objeto, e só a policy decide quem lê.
resource "aws_s3_bucket_ownership_controls" "avatars" {
  bucket = aws_s3_bucket.avatars.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# ACL pública continua bloqueada; só a policy pública é permitida (a de leitura dos avatares, abaixo).
resource "aws_s3_bucket_public_access_block" "avatars" {
  bucket = aws_s3_bucket.avatars.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_server_side_encryption_configuration" "avatars" {
  bucket = aws_s3_bucket.avatars.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Sem versões: o backend apaga o avatar antigo quando o usuário troca, e uma versão guardada manteria a foto.
resource "aws_s3_bucket_versioning" "avatars" {
  bucket = aws_s3_bucket.avatars.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_policy" "avatars" {
  bucket = aws_s3_bucket.avatars.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "LeituraPublicaDosAvatares"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = local.public_objects_arn
      },
      {
        Sid       = "SoHttps"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [local.bucket_arn, "${local.bucket_arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
    ]
  })

  # Bucket novo nasce com o bloqueio público total: a policy pública só entra depois de o bloqueio ser ajustado.
  depends_on = [aws_s3_bucket_public_access_block.avatars]
}
