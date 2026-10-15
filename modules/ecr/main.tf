# Repositório de imagens de um serviço (backend na MS-28, frontend na MS-29). A tag é o commit curto do repositório de
# origem (MS-94) e não pode ser sobrescrita: cada deploy aponta para uma imagem exata, e o rollback é voltar a tag.

resource "aws_ecr_repository" "main" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = var.ecr_tags
}

# Guarda só as últimas imagens: o resto vira custo de armazenamento sem uso.
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Manter as ${var.ecr_keep_images} imagens mais recentes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_keep_images
        }
        action = { type = "expire" }
      },
    ]
  })
}
