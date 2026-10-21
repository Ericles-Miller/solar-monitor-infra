# Política gerenciada da AWS: repassa à origem todos os cabeçalhos (inclusive o Host), cookies e query strings do
# navegador. Com o Host original, o Next monta os endereços absolutos com o domínio do CloudFront, não com o do ALB.
data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}
