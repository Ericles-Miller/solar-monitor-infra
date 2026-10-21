# HTTPS sem domínio próprio: o CloudFront atende em https://<id>.cloudfront.net com o certificado padrão da AWS
# (renova sozinho) e repassa ao ALB por HTTP. Quando o domínio do cliente chegar (MS-30), ele entra aqui como alias,
# com um certificado do ACM.

# Sem cache: a API e as telas respondem por usuário. Com os três TTL em 0 a AWS não deixa pôr cabeçalho na chave,
# então o máximo é 1 s e o padrão 0 (sem Cache-Control da origem, nada fica guardado). O Authorization precisa estar
# na chave: num GET, o CloudFront só repassa esse cabeçalho à origem se ele fizer parte da chave do cache.
resource "aws_cloudfront_cache_policy" "no_cache" {
  name        = "${var.cdn_name}-sem-cache"
  comment     = "Sem cache; Authorization chega ao backend também no GET"
  min_ttl     = 0
  default_ttl = 0
  max_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Authorization"]
      }
    }

    cookies_config {
      cookie_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

resource "aws_cloudfront_distribution" "main" {
  enabled         = true
  comment         = var.cdn_name
  is_ipv6_enabled = true
  http_version    = "http2and3"
  # Inclui os pontos de presença da América do Sul (o cliente e a usina estão em SP).
  price_class = "PriceClass_All"
  tags        = var.cdn_tags

  origin {
    origin_id   = "alb"
    domain_name = var.cdn_origin_domain_name

    custom_origin_config {
      http_port              = var.cdn_origin_http_port
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id         = "alb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = aws_cloudfront_cache_policy.no_cache.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
    compress                 = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
