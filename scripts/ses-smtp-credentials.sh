#!/usr/bin/env bash
# Gera a chave do usuário SMTP do SES (MS-91) e grava MAIL_USER e MAIL_PASSWORD no Parameter Store.
# A chave não é mostrada, não passa pelo estado do Terraform nem pela lista de processos: o pedido ao Parameter Store vai
# por um arquivo temporário que só o seu usuário lê, apagado logo depois (o AWS CLI não lê JSON da entrada padrão).
# Roda uma vez, depois do `terraform apply` que cria o usuário e os parâmetros. A chave não expira.
#
# Uso:  scripts/ses-smtp-credentials.sh            (primeira vez)
#       scripts/ses-smtp-credentials.sh --replace  (troca a chave: cria a nova, grava e apaga a antiga)
# Depois de gravar, reinicie o serviço do backend para ele ler os valores novos.
set -euo pipefail

PROFILE="${AWS_PROFILE:-ericles-dev}"
REGION="${AWS_REGION:-sa-east-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
USER_NAME="solar-monitor-${ENVIRONMENT}-ses-smtp"
PARAMETER_PREFIX="/solar-monitor/${ENVIRONMENT}"
REPLACE=false
[ "${1:-}" = "--replace" ] && REPLACE=true

aws_cli() { aws --profile "$PROFILE" --region "$REGION" "$@"; }

if ! aws_cli iam get-user --user-name "$USER_NAME" >/dev/null 2>&1; then
  echo "Usuário $USER_NAME não existe: rode o terraform apply do módulo email antes." >&2
  exit 1
fi
for name in MAIL_USER MAIL_PASSWORD; do
  if ! aws_cli ssm get-parameter --name "$PARAMETER_PREFIX/$name" --query Parameter.Name --output text >/dev/null 2>&1; then
    echo "Parâmetro $PARAMETER_PREFIX/$name não existe: rode o terraform apply do módulo email antes." >&2
    exit 1
  fi
done

old_keys=$(aws_cli iam list-access-keys --user-name "$USER_NAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text)
if [ -n "$old_keys" ] && [ "$REPLACE" = false ]; then
  echo "O usuário $USER_NAME já tem chave. Para trocar, rode de novo com --replace." >&2
  exit 1
fi

umask 077
tmp_dir=$(mktemp -d)
new_key_id=""

# Sempre apaga o arquivo temporário. Se falhar depois de criar a chave nova, apaga a chave também (o segredo dela se
# perderia): os parâmetros ficam como estavam e dá para rodar de novo.
cleanup() {
  local status=$?
  rm -rf "$tmp_dir"
  if [ "$status" -ne 0 ] && [ -n "$new_key_id" ]; then
    aws_cli iam delete-access-key --user-name "$USER_NAME" --access-key-id "$new_key_id" || true
    echo "Falhou: a chave nova foi apagada. Rode o script de novo." >&2
  fi
}
trap cleanup EXIT

key_json=$(aws_cli iam create-access-key --user-name "$USER_NAME" --output json)
new_key_id=$(printf '%s' "$key_json" | python3 -c 'import json, sys; print(json.load(sys.stdin)["AccessKey"]["AccessKeyId"])')

# Monta o pedido do put-parameter. A senha SMTP é derivada da chave secreta com o algoritmo da AWS
# (assinatura v4 de "SendRawEmail" na região, precedida do byte de versão 0x04).
to_parameter() {
  python3 -c '
import base64, hashlib, hmac, json, sys

name, region, kind = sys.argv[1:4]
key = json.load(sys.stdin)["AccessKey"]

def sign(secret, message):
    return hmac.new(secret, message.encode("utf-8"), hashlib.sha256).digest()

if kind == "user":
    value = key["AccessKeyId"]
else:
    signature = sign(("AWS4" + key["SecretAccessKey"]).encode("utf-8"), "11111111")
    for part in (region, "ses", "aws4_request", "SendRawEmail"):
        signature = sign(signature, part)
    value = base64.b64encode(bytes([0x04]) + signature).decode("utf-8")

print(json.dumps({"Name": name, "Value": value, "Type": "SecureString", "Overwrite": True}))
' "$1" "$REGION" "$2"
}

put_parameter() {
  local request="$tmp_dir/request.json"
  printf '%s' "$key_json" | to_parameter "$1" "$2" >"$request"
  aws_cli ssm put-parameter --cli-input-json "file://$request" --output text >/dev/null
  rm -f "$request"
}

put_parameter "$PARAMETER_PREFIX/MAIL_USER" user
put_parameter "$PARAMETER_PREFIX/MAIL_PASSWORD" password
unset key_json
new_key_id="" # deu certo: a chave nova fica

for old_key in $old_keys; do
  aws_cli iam delete-access-key --user-name "$USER_NAME" --access-key-id "$old_key"
done

echo "MAIL_USER e MAIL_PASSWORD gravados em $PARAMETER_PREFIX."
[ -n "$old_keys" ] && echo "Chave antiga apagada."
echo "Reinicie o serviço do backend para ele ler os valores novos."
