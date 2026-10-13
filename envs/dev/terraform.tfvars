# Valores do ambiente dev. NUNCA coloque segredo aqui: segredos vão no Parameter Store (ver README).

region = "sa-east-1"

# Decidido pelo Ericles em 12/10/2026.
budget_limit_usd = 50

# budget_alert_emails vem da variável de ambiente TF_VAR_budget_alert_emails (ver README).
# Não defina aqui: este arquivo tem prioridade sobre o ambiente e esconderia o valor exportado.
