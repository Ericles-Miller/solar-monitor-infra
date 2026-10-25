# solar-monitor-infra

Infraestrutura do **Solar Monitor** (monitoramento de usinas solares) na AWS, com Terraform. Um único projeto cria o ambiente do backend ([`solar-monitor`](../solar-monitor)) e do frontend ([`solar-monitor-web`](../solar-monitor-web)).

**Por enquanto só existe o ambiente `dev`**, na região `sa-east-1` (São Paulo). Decisões, serviços escolhidos e o motivo de cada um: `docs/arquitetura/09-infra-terraform-dev.md`.

## Estrutura

Segue o padrão do repositório [`terraform_infra`](https://github.com/Ericles-Miller/terraform_infra): o Terraform do ambiente fica na **raiz** e cada bloco de infraestrutura é um módulo.

| Arquivo / pasta | O que é |
|---|---|
| `providers.tf` | Bloco `terraform` (versão do provider fixada, backend S3) e o `provider "aws"` com as `default_tags` |
| `variables.tf` | Variáveis do ambiente, com `type`, `description` e `default` |
| `main.tf` | Chamada dos módulos |
| `datasource.tf` | Data sources |
| `output.tf` | Saídas do ambiente |
| `modules/<nome>/` | Um módulo por bloco: `main.tf`, `variables.tf`, `outputs.tf`, `datasource.tf` (só se tiver data source) e `tests/` |
| `bootstrap/` | Cria o bucket S3 que guarda o estado. Roda **uma vez por conta**, com estado local |

Módulos de hoje:

| Módulo | Task | O que cria |
|---|---|---|
| `budget` | MS-87 | Orçamento mensal com alerta de custo por e-mail |
| `network` | MS-88 | VPC em 2 zonas (sub-redes públicas e privadas, sem NAT), rotas e os security groups do ALB, das tarefas e do banco |
| `alb` | MS-88 | ALB com os target groups do backend e do frontend e os listeners HTTP (`:80` → frontend, `:8080` → backend) |
| `cdn` | — | CloudFront na frente de um listener do ALB: HTTPS sem domínio (`https://<id>.cloudfront.net`, certificado da AWS), sem cache e com o `Authorization` chegando ao backend; um para o front e outro para a API |
| `ecs_cluster` | MS-88 | Cluster ECS (Fargate) e os grupos de log de cada serviço |
| `avatars` | MS-90 | Bucket S3 dos avatares: leitura pública só de `avatars/*`, sem ACL, criptografado, sem versões e só por HTTPS |
| `database` | MS-89 | RDS PostgreSQL 15 nas sub-redes privadas; senha gerada pelo Terraform, fora do estado, no Parameter Store, sem troca automática |
| `ecr` | MS-28 | Repositório de imagens com tag imutável, scan ao enviar e só as 10 últimas imagens |
| `ecs_service` | MS-28 | Serviço Fargate genérico atrás do ALB: papéis IAM, task definition com segredos do Parameter Store, health check, ECS Exec e rollback automático |
| `backend_secrets` | MS-28 | Segredos do backend: JWT gerados pelo Terraform e as credenciais da Sungrow (preenchidas por `scripts/backend-secrets.sh`) |
| `github_deploy` | MS-94 | Papel que o GitHub Actions assume (OIDC) para publicar um serviço no ECS; só a `develop` do repositório |

Falta só o domínio com HTTPS (MS-30), que depende do domínio do cliente. O front (MS-29) reaproveita os módulos `ecr`, `ecs_service` e `github_deploy` do backend.

### Convenções

- **Variáveis de módulo levam o nome do módulo como prefixo** (`budget_name`, `budget_limit_usd`, `budget_tags`). Todo módulo aceita `<prefixo>_tags` (`map(string)`, padrão `{}`) para tags além das `default_tags`.
- **Nomes de recurso levam o ambiente**: `solar-monitor-${var.environment}-<nome>`.
- Outputs com `value`, `sensitive` e `description`.
- **Valores fixos vão no `default` do `variables.tf`.** Arquivos `*.tfvars` ficam fora do git.
- O `.terraform.lock.hcl` é versionado.

## Pré-requisitos

- **Terraform >= 1.11** (a trava do estado usa o lockfile nativo do S3, desde o 1.10; a senha do banco usa atributos write-only, desde o 1.11).
- **AWS CLI v2** com o perfil **`ericles-dev`** configurado e com permissão para criar os recursos. O perfil vem da variável `aws_profile` (padrão `ericles-dev`) e, no backend, fica fixo no `providers.tf`: não precisa de `export AWS_PROFILE`. Nenhuma credencial fica no código.

Para conferir a conta antes de qualquer plan: `aws sts get-caller-identity --profile ericles-dev`.

## Primeira vez numa conta

### 1. Bucket do estado (bootstrap)

```sh
terraform -chdir=bootstrap init
terraform -chdir=bootstrap apply
```

Cria `solar-monitor-tfstate-<id-da-conta>`: versionado, criptografado, sem acesso público e só por HTTPS. O estado do bootstrap fica local (`bootstrap/terraform.tfstate`, fora do git). Se ele se perder, o bucket continua lá; para administrá-lo de novo, use `terraform import`.

Numa conta nova, troque o `bucket` do backend no `providers.tf` pelo output `state_bucket` do bootstrap.

### 2. E-mail dos alertas de custo

Quem recebe os alertas **não fica no repositório**: vem da variável de ambiente `TF_VAR_budget_alert_emails`, uma lista em formato HCL. Coloque no seu `~/.zshrc` (ou equivalente):

```sh
export TF_VAR_budget_alert_emails='["voce@exemplo.com"]'
```

- Sem a variável, o `plan` pergunta o valor (ou para com erro, com `-input=false`). Lista vazia ou e-mail inválido param com "Informe ao menos um e-mail válido".
- Para trocar quem recebe, mude a variável e rode `plan` + `apply`: a assinatura só muda na AWS depois do `apply`. Quem rodar o `apply` com outro valor troca os destinatários.
- O e-mail fica gravado no estado (no S3), não no git.

### 3. Remetente dos e-mails (SMTP do Gmail)

O backend manda os e-mails (confirmação de conta, esqueci a senha, alarmes) pelo **SMTP do Gmail** (`smtp.gmail.com:587`), com uma conta do Gmail como remetente. Ele entrega para qualquer endereço, até ~500 e-mails por dia. Desde 21/10/2026 o SES não é usado.

Como o e-mail do alerta, a conta que envia vem de uma variável de ambiente:

```sh
export TF_VAR_mail_sender_email='voce@gmail.com'
```

A conta precisa de uma **senha de app** (<https://myaccount.google.com/apppasswords>, com a verificação em duas etapas ligada). Depois do primeiro `apply`, grave-a uma vez:

```sh
scripts/mail-password.sh
```

O script pede a senha sem mostrá-la e a grava em `MAIL_PASSWORD` no Parameter Store. Para trocar, gere outra senha de app, rode o script de novo e reinicie o backend.

### 4. Liberar o custo na conta de gerenciamento (manual, uma vez)

A conta do dev (`779257801295`) é **membro de uma AWS Organization**. Orçamentos, Cost Explorer e tags de custo são controlados pela **conta de gerenciamento** (a pagadora, `471112556317`). Sem a liberação abaixo, o `apply` do orçamento falha com `AccessDeniedException: Account ... is a linked account`.

Logado na **conta de gerenciamento** (não na do dev):

1. **Billing and Cost Management** → **Cost Explorer**: abra uma vez para ativá-lo.
2. **Billing and Cost Management** → **Cost Management preferences** → **Linked account access**: dê às contas-membro acesso ao Cost Explorer e aos orçamentos.
3. **Billing and Cost Management** → **Cost allocation tags** → **User-defined cost allocation tags**: marque **`Project`** e clique em **Activate**.

O alerta de custo conta só os recursos com a tag `Project = solar-monitor`, para não misturar com outros projetos. A tag só aparece na lista do passo 3 depois que a AWS processa a cobrança de algum recurso com ela (até 24 h), e a ativação pode levar mais 24 h para valer. **Até lá, o orçamento mostra custo zero e não alerta.**

Para conferir a liberação, na conta do dev: `aws budgets describe-budgets --account-id <id-da-conta-dev> --profile ericles-dev` não pode responder `AccessDeniedException`.

### 5. Subir o dev (primeira vez)

Todo `plan`/`apply` recebe a tag da imagem do backend e a do front (`-var backend_image_tag=<commit> -var frontend_image_tag=<commit>`, nunca `latest`). Leia o `plan` antes de aplicar: o `apply` cria recursos reais e cobrados (~US$ 107 por mês com o back e o front no ar).

O front precisa do endereço da API **no build** da imagem, e esse endereço é o do CloudFront da API (HTTPS, na frente do ALB). Por isso o ALB e o CloudFront sobem antes das imagens:

```sh
BACK_TAG=$(git -C ../solar-monitor rev-parse --short=7 develop)
FRONT_TAG=$(git -C ../solar-monitor-web rev-parse --short=7 develop)

# 1. Rede inteira, ALB, CloudFront (HTTPS), repositórios das imagens e parâmetros dos segredos. A rede vai inteira:
#    só com o ALB, o internet gateway e as rotas ficariam de fora, e a AWS não cria ALB público em VPC sem internet
#    gateway. O CloudFront leva uns 3 minutos para publicar.
terraform apply -var backend_image_tag=$BACK_TAG -var frontend_image_tag=$FRONT_TAG \
  -target=module.network -target=module.alb -target=module.frontend_cdn -target=module.backend_cdn \
  -target=module.backend_ecr -target=module.frontend_ecr -target=module.backend_secrets

# 2. Credenciais da Sungrow, copiadas do .env do backend (os JWT o Terraform gera sozinho), e a senha de app do Gmail
scripts/backend-secrets.sh ../solar-monitor/.env
scripts/mail-password.sh

# 3. Primeiras imagens (ARM64), do develop de cada repositório
ACCOUNT=$(aws sts get-caller-identity --query Account --output text --profile ericles-dev)
REGISTRY="$ACCOUNT.dkr.ecr.sa-east-1.amazonaws.com"
API_URL=$(terraform output -raw backend_url)   # https://<id>.cloudfront.net da API
aws ecr get-login-password --profile ericles-dev --region sa-east-1 | docker login --username AWS --password-stdin "$REGISTRY"
git -C ../solar-monitor checkout develop && git -C ../solar-monitor-web checkout develop
docker build --provenance=false --platform linux/arm64 -t "$REGISTRY/solar-monitor-api:$BACK_TAG" ../solar-monitor
docker push "$REGISTRY/solar-monitor-api:$BACK_TAG"
docker build --provenance=false --platform linux/arm64 --build-arg NEXT_PUBLIC_API_URL="$API_URL" -t "$REGISTRY/solar-monitor-web:$FRONT_TAG" ../solar-monitor-web
docker push "$REGISTRY/solar-monitor-web:$FRONT_TAG"

# 4. O resto: banco (~10 min), os dois serviços e os papéis do deploy pelo GitHub
terraform plan -var backend_image_tag=$BACK_TAG -var frontend_image_tag=$FRONT_TAG -out=dev.tfplan
terraform apply dev.tfplan
```

Depois, pelo ECS Exec (precisa do `session-manager-plugin`: `brew install --cask session-manager-plugin`):

```sh
TASK=$(aws ecs list-tasks --cluster solar-monitor-dev --service-name solar-monitor-dev-api --query 'taskArns[0]' --output text --profile ericles-dev --region sa-east-1)
exec_api() { aws ecs execute-command --cluster solar-monitor-dev --task "$TASK" --container api --interactive --command "$1" --profile ericles-dev --region sa-east-1; }

exec_api "node dist/scripts/import-plant.js 1569493"                    # mostra o código de vínculo
for k in 1569493_1_1_1 1569493_1_2_1 1569493_1_3_1 1569493_1_4_1 1569493_1_5_1; do
  exec_api "node dist/scripts/set-string-inputs.js $k 1-23"             # entradas em uso (MS-96)
done
```

O `import-plant` de uma usina **nova** já traz o histórico de eventos da Sungrow desde o comissionamento (MS-101): ~20 chamadas e menos de 1 min. Para uma usina importada **antes** dessa versão (como a UFV JAC 03, importada em 21/10/2026), rode uma vez:

```sh
exec_api "node dist/scripts/backfill-manufacturer-events.js 1569493"    # ou --from AAAA-MM
```

Se a Sungrow cortar no meio (limite de chamadas), o comando diz o mês em que parou e como continuar. Rodar de novo não duplica evento.

**O histórico de energia** (MS-77, as barras por mês, ano e vida útil) se completa **sozinho**. Às 00:30, o backend fecha o dia anterior e busca até 60 dias antigos por usina. Na UFV JAC 03, ~565 dias levam ~10 noites, sem ninguém rodar nada. Para ter tudo de uma vez (~20 min, 1 chamada por dia):

```sh
exec_api "node dist/scripts/energy-backfill.js 1569493"                 # ou --from AAAA-MM-DD
```

`ENERGY_NIGHTLY_BACKFILL_DAYS` (padrão 60, 0 desliga) muda quantos dias o job busca por noite.

### 6. Ligar o CI/CD (GitHub Actions)

O workflow `.github/workflows/ci.yml` do `solar-monitor` e do `solar-monitor-web`: push na **`develop` publica no dev**; push na **`main` só valida** (testes e semantic release). Em cada repositório, em **Settings → Secrets and variables → Actions**:

| Tipo | Nome | Valor |
|---|---|---|
| Secret | `ROLE_ASSUME` | `github_role_arn` de `terraform output -json backend` (no `solar-monitor`) ou de `terraform output -json frontend` (no `solar-monitor-web`) |
| Secret | `AWS_REGION` | `sa-east-1` |
| Variável | `DEPLOY_ENABLED` | `true` (sem ela, o push só testa e não publica) |
| Variável (só front) | `NEXT_PUBLIC_API_URL` | `terraform output -raw backend_url` |

O papel do deploy só aceita a `develop` daquele repositório e só pode enviar a imagem ao ECR do serviço, registrar a task definition e atualizar o serviço. A imagem ARM64 é gerada com emulação: o primeiro build é lento, os seguintes usam o cache.

## Dia a dia

```sh
terraform fmt -recursive   # formatar
terraform validate         # validar
terraform plan -var backend_image_tag=<tag no ar> -var frontend_image_tag=<tag no ar>   # ver o que vai mudar
```

Quem publica as imagens é o CI; as tags no `plan` só importam na primeira subida. Para usar as que estão no ar (e o `plan` não mostrar diferença na task definition):

```sh
for s in api web; do aws ecs describe-task-definition --task-definition solar-monitor-dev-$s --query 'taskDefinition.containerDefinitions[0].image' --output text --profile ericles-dev --region sa-east-1; done
```

Sem acesso à AWS ainda dá para validar: `terraform init -backend=false` e depois `validate`.

Os módulos com pasta `tests/` têm testes que rodam **sem acesso à AWS** (provider simulado):

```sh
for m in budget network alb cdn ecs_cluster avatars database ecr ecs_service backend_secrets github_deploy; do
  terraform -chdir=modules/$m init -backend=false && terraform -chdir=modules/$m test
done
```

Cada módulo tem o próprio `.terraform.lock.hcl`, **cópia do lock da raiz**, para os testes rodarem com a mesma versão do provider do ambiente. Ao trocar a versão do provider na raiz, copie o lock novo para os módulos.

## Operar o dev

- **Publicar versão nova:** merge ou push na `develop` do repositório. O workflow testa, gera a imagem com a tag do commit, publica e espera o serviço ficar saudável. Se a versão nova não subir, o ECS volta sozinho para a anterior e o workflow falha.
- **Rollback:** em **Actions**, abra a execução do commit bom e **Re-run all jobs**. A imagem daquele commit já está no ECR, então o workflow pula o build e só publica. Sem o GitHub: `aws ecs update-service --cluster solar-monitor-dev --service solar-monitor-dev-api --task-definition solar-monitor-dev-api:<revisão anterior>`.
- **Mudar uma variável do backend (ou acrescentar um segredo):** mude no Terraform e aplique; a revisão nova da task definition entra no próximo deploy do CI. Para valer na hora, rode de novo o último workflow da `develop` (**Re-run all jobs**): ele parte da revisão mais nova. (O `--force-new-deployment` não serve aqui: ele reinicia com a revisão que já está no ar.)
- **Trocar um segredo:** JWT e senha do banco: aumente `backend_secrets_jwt_version` ou `database_password_version`, aplique e reinicie o backend. Sungrow: `scripts/backend-secrets.sh`. Senha do SMTP: `scripts/mail-password.sh`. Depois, `--force-new-deployment`.
- **Pausar o dev para economizar:** `aws ecs update-service ... --desired-count 0` no backend (e no front) e `aws rds stop-db-instance --db-instance-identifier solar-monitor-dev-db`. Parado, o RDS só cobra o disco; a AWS religa sozinha depois de 7 dias. Para voltar: `aws rds start-db-instance ...` e `--desired-count 1`. O próximo `apply` também volta o backend para 1 tarefa.
- **Logs:** `aws logs tail /ecs/solar-monitor-dev/api --follow --profile ericles-dev --region sa-east-1`.
- **Dados reais da UFV JAC 03:** não desvincular a usina nem excluir a conta que a tem, e não rodar `destroy` (o banco tem proteção contra exclusão e snapshot final). Com o backend do dev no ar, o backend local não deve coletar junto (`COLLECTOR_INTERVAL_MINUTES` bem alto no `.env`), para não dobrar as chamadas à Sungrow.

## Regras

- **Nenhum segredo** neste repositório ou em output. Segredos vão no Parameter Store (MS-28).
- `terraform apply` e `destroy` só com o plano lido e conferido.
- **Só o ambiente dev existe:** a variável `environment` só aceita `dev`, porque o backend aponta para o estado do dev. O prod vai ter estado próprio.
- O backend roda com **uma única tarefa**: o coletor fica dentro do processo e duas instâncias dobrariam as chamadas à Sungrow.
- O dev guarda dados **reais** da UFV JAC 03. Cuidado com `destroy`.
