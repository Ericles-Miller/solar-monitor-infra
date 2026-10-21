#!/usr/bin/env bash
# Grava a senha do SMTP do backend (MAIL_PASSWORD) no Parameter Store: a senha de app da conta do Gmail que envia os
# e-mails (TF_VAR_mail_sender_email). A senha é digitada sem aparecer na tela, não passa pelo estado do Terraform nem
# pela lista de processos: o pedido vai por um arquivo temporário que só o seu usuário lê, apagado logo depois.
#
# Senha de app: https://myaccount.google.com/apppasswords (exige a verificação em duas etapas ligada na conta).
#
# Uso:  scripts/mail-password.sh
# Roda depois do `terraform apply` que cria o parâmetro, e de novo só se a senha de app mudar. Depois de gravar,
# publique o backend de novo para ele ler o valor novo (README, "Operar o dev").
set -euo pipefail

PROFILE="${AWS_PROFILE:-ericles-dev}"
REGION="${AWS_REGION:-sa-east-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
PARAMETER="/solar-monitor/${ENVIRONMENT}/MAIL_PASSWORD"

aws_cli() { aws --profile "$PROFILE" --region "$REGION" "$@"; }

if ! aws_cli ssm get-parameter --name "$PARAMETER" --query Parameter.Name --output text >/dev/null 2>&1; then
  echo "Parâmetro $PARAMETER não existe: rode o terraform apply antes." >&2
  exit 1
fi

read -r -s -p "Senha de app do Gmail (não aparece na tela): " password
echo
# O Google mostra a senha de app em 4 blocos com espaço; o SMTP aceita sem os espaços.
password="${password// /}"
if [ "${#password}" -ne 16 ]; then
  echo "A senha de app do Google tem 16 letras. Confira e rode de novo." >&2
  exit 1
fi

umask 077
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

PARAMETER="$PARAMETER" PASSWORD="$password" python3 -c '
import json, os
print(json.dumps({"Name": os.environ["PARAMETER"], "Value": os.environ["PASSWORD"], "Type": "SecureString", "Overwrite": True}))
' >"$tmp_dir/request.json"
unset password

aws_cli ssm put-parameter --cli-input-json "file://$tmp_dir/request.json" --output text >/dev/null
echo "Senha do SMTP gravada em $PARAMETER."
echo "Publique o backend de novo para ele ler o valor novo."
