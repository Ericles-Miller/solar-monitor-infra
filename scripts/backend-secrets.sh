#!/usr/bin/env bash
# Copia as credenciais da Sungrow do .env do backend para o Parameter Store (MS-28): SUNGROW_APPKEY,
# SUNGROW_ACCESS_KEY, SUNGROW_USER_ACCOUNT e SUNGROW_USER_PASSWORD. Os valores não são mostrados, não passam pelo estado
# do Terraform nem pela lista de processos: cada pedido vai por um arquivo temporário que só o seu usuário lê, apagado
# logo depois. Os segredos JWT não entram aqui: o Terraform gera os dois.
#
# Uso:  scripts/backend-secrets.sh ../solar-monitor/.env
# Roda uma vez, depois do `terraform apply` que cria os parâmetros (e de novo só se a credencial da Sungrow mudar).
# Depois de gravar, reinicie o serviço do backend para ele ler os valores novos.
set -euo pipefail

ENV_FILE="${1:-}"
PROFILE="${AWS_PROFILE:-ericles-dev}"
REGION="${AWS_REGION:-sa-east-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
PARAMETER_PREFIX="/solar-monitor/${ENVIRONMENT}"
NAMES=(SUNGROW_APPKEY SUNGROW_ACCESS_KEY SUNGROW_USER_ACCOUNT SUNGROW_USER_PASSWORD)

if [ -z "$ENV_FILE" ] || [ ! -f "$ENV_FILE" ]; then
  echo "Uso: scripts/backend-secrets.sh <caminho do .env do backend>" >&2
  exit 1
fi

aws_cli() { aws --profile "$PROFILE" --region "$REGION" "$@"; }

for name in "${NAMES[@]}"; do
  if ! aws_cli ssm get-parameter --name "$PARAMETER_PREFIX/$name" --query Parameter.Name --output text >/dev/null 2>&1; then
    echo "Parâmetro $PARAMETER_PREFIX/$name não existe: rode o terraform apply antes." >&2
    exit 1
  fi
done

umask 077
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

# Lê NOME=valor do .env (aspas em volta saem) e monta o pedido do put-parameter. Valor vazio para o script: o
# backend não sobe sem essas credenciais.
to_parameter() {
  python3 -c '
import json, sys

env_file, name, parameter = sys.argv[1:4]
value = None
with open(env_file, encoding="utf-8") as lines:
    for line in lines:
        line = line.strip()
        if line.startswith(name + "="):
            value = line[len(name) + 1:].strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"\x27":
                value = value[1:-1]
if not value:
    sys.exit(f"{name} está vazio ou não existe em {env_file}")

print(json.dumps({"Name": parameter, "Value": value, "Type": "SecureString", "Overwrite": True}))
' "$ENV_FILE" "$1" "$PARAMETER_PREFIX/$1"
}

# Monta todos os pedidos antes de gravar o primeiro: se faltar algum valor, nada muda.
for name in "${NAMES[@]}"; do
  to_parameter "$name" >"$tmp_dir/$name.json"
done
for name in "${NAMES[@]}"; do
  aws_cli ssm put-parameter --cli-input-json "file://$tmp_dir/$name.json" --output text >/dev/null
  rm -f "$tmp_dir/$name.json"
done

echo "Credenciais da Sungrow gravadas em $PARAMETER_PREFIX (${#NAMES[@]} parâmetros)."
echo "Reinicie o serviço do backend para ele ler os valores novos."
