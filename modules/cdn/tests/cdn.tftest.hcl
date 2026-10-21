# Roda sem acesso à AWS: terraform -chdir=modules/cdn init && terraform -chdir=modules/cdn test
mock_provider "aws" {
  mock_data "aws_cloudfront_origin_request_policy" {
    defaults = { id = "216adef6-5c7f-47e4-b989-5492eafa07d3" }
  }
}

variables {
  cdn_name               = "solar-monitor-dev-web"
  cdn_origin_domain_name = "solar-monitor-dev-alb-123.sa-east-1.elb.amazonaws.com"
  cdn_origin_http_port   = 80
}

run "https_no_navegador_e_http_ate_o_alb" {
  command = plan

  assert {
    condition     = aws_cloudfront_distribution.main.default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https"
    error_message = "Quem chegar por HTTP precisa ser levado ao HTTPS."
  }

  assert {
    condition     = one(aws_cloudfront_distribution.main.origin).custom_origin_config[0].origin_protocol_policy == "http-only" && one(aws_cloudfront_distribution.main.origin).custom_origin_config[0].http_port == 80
    error_message = "O ALB só tem HTTP: a origem precisa ser http-only, na porta do listener."
  }

  assert {
    condition     = aws_cloudfront_distribution.main.viewer_certificate[0].cloudfront_default_certificate == true
    error_message = "Sem domínio, o certificado é o padrão do CloudFront."
  }

  assert {
    condition     = aws_cloudfront_distribution.main.price_class == "PriceClass_All"
    error_message = "A distribuição precisa usar os pontos de presença da América do Sul."
  }
}

run "api_na_8080_com_todos_os_metodos" {
  command = plan

  variables {
    cdn_name             = "solar-monitor-dev-api"
    cdn_origin_http_port = 8080
  }

  assert {
    condition     = one(aws_cloudfront_distribution.main.origin).custom_origin_config[0].http_port == 8080
    error_message = "A API fica no listener 8080 do ALB."
  }

  assert {
    condition     = toset(aws_cloudfront_distribution.main.default_cache_behavior[0].allowed_methods) == toset(["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"])
    error_message = "A API usa POST, PUT, PATCH e DELETE, e o navegador manda OPTIONS no CORS."
  }
}

run "sem_cache_e_com_authorization_na_chave" {
  command = plan

  assert {
    condition     = aws_cloudfront_cache_policy.no_cache.default_ttl == 0 && aws_cloudfront_cache_policy.no_cache.min_ttl == 0
    error_message = "Sem Cache-Control da origem, nada pode ficar guardado."
  }

  assert {
    condition     = contains(aws_cloudfront_cache_policy.no_cache.parameters_in_cache_key_and_forwarded_to_origin[0].headers_config[0].headers[0].items, "Authorization")
    error_message = "Sem o Authorization na chave, os GET autenticados chegam ao backend sem o token."
  }

  assert {
    condition     = aws_cloudfront_cache_policy.no_cache.parameters_in_cache_key_and_forwarded_to_origin[0].query_strings_config[0].query_string_behavior == "all"
    error_message = "As query strings (filtros, datas) precisam chegar ao backend."
  }
}

run "recusa_porta_que_o_cloudfront_nao_aceita" {
  command = plan

  variables {
    cdn_origin_http_port = 22
  }

  expect_failures = [var.cdn_origin_http_port]
}
