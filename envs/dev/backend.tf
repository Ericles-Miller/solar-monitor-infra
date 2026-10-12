# Estado no S3 criado pelo bootstrap/. O nome do bucket tem o id da conta e vem do backend.hcl:
#   terraform init -backend-config=backend.hcl
# use_lockfile = trava nativa do S3 (Terraform >= 1.10), sem DynamoDB.
terraform {
  backend "s3" {
    key          = "dev/terraform.tfstate"
    region       = "sa-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
