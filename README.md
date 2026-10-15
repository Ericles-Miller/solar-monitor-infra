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
| `ecs_cluster` | MS-88 | Cluster ECS (Fargate) e os grupos de log de cada serviço |
| `avatars` | MS-90 | Bucket S3 dos avatares: leitura pública só de `avatars/*`, sem ACL, criptografado, sem versões e só por HTTPS |
| `database` | MS-89 | RDS PostgreSQL 15 nas sub-redes privadas; senha gerada pelo Terraform, fora do estado, no Parameter Store, sem troca automática |
| `email` | MS-91 | SES: remetente verificado, usuário SMTP que só envia com ele e os parâmetros `MAIL_USER` e `MAIL_PASSWORD` (preenchidos por `scripts/ses-smtp-credentials.sh`) |
| `ecr` | MS-28 | Repositório de imagens com tag imutável, scan ao enviar e só as 10 últimas imagens |
| `ecs_service` | MS-28 | Serviço Fargate genérico atrás do ALB: papéis IAM, task definition com segredos do Parameter Store, health check, ECS Exec e rollback automático |
| `backend_secrets` | MS-28 | Segredos do backend: JWT gerados pelo Terraform e as credenciais da Sungrow (preenchidas por `scripts/backend-secrets.sh`) |

Os próximos entram com as tasks do épico MS-6: frontend no ECS (MS-29, reaproveitando `ecr` e `ecs_service`), scripts de deploy (MS-94) e domínio com HTTPS (MS-30).

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

### 3. Remetente dos e-mails

Como o e-mail do alerta, o remetente do backend e os destinatários de teste do sandbox do SES vêm de variáveis de ambiente:

```sh
export TF_VAR_mail_sender_email='voce@exemplo.com'
export TF_VAR_mail_test_recipients='["outro@exemplo.com"]'   # opcional
```

Depois do primeiro `apply`, a AWS manda um link de confirmação para cada endereço: clique nele. Em seguida, rode uma vez:

```sh
scripts/ses-smtp-credentials.sh
```

Ele cria a chave do usuário SMTP e grava `MAIL_USER` e `MAIL_PASSWORD` no Parameter Store, sem mostrar nada. Para trocar a chave: `scripts/ses-smtp-credentials.sh --replace` e reinicie o backend.

### 4. Liberar o custo na conta de gerenciamento (manual, uma vez)

A conta do dev (`779257801295`) é **membro de uma AWS Organization**. Orçamentos, Cost Explorer e tags de custo são controlados pela **conta de gerenciamento** (a pagadora, `471112556317`). Sem a liberação abaixo, o `apply` do orçamento falha com `AccessDeniedException: Account ... is a linked account`.

Logado na **conta de gerenciamento** (não na do dev):

1. **Billing and Cost Management** → **Cost Explorer**: abra uma vez para ativá-lo.
2. **Billing and Cost Management** → **Cost Management preferences** → **Linked account access**: dê às contas-membro acesso ao Cost Explorer e aos orçamentos.
3. **Billing and Cost Management** → **Cost allocation tags** → **User-defined cost allocation tags**: marque **`Project`** e clique em **Activate**.

O alerta de custo conta só os recursos com a tag `Project = solar-monitor`, para não misturar com outros projetos. A tag só aparece na lista do passo 3 depois que a AWS processa a cobrança de algum recurso com ela (até 24 h), e a ativação pode levar mais 24 h para valer. **Até lá, o orçamento mostra custo zero e não alerta.**

Para conferir a liberação, na conta do dev: `aws budgets describe-budgets --account-id <id-da-conta-dev> --profile ericles-dev` não pode responder `AccessDeniedException`.

### 5. Subir o dev

```sh
terraform init
terraform plan -out=dev.tfplan
terraform apply dev.tfplan
```

Leia o `plan` antes de aplicar. O `apply` cria recursos reais e cobrados.

## Dia a dia

```sh
terraform fmt -recursive   # formatar
terraform validate         # validar
terraform plan             # ver o que vai mudar
```

Sem acesso à AWS ainda dá para validar: `terraform init -backend=false` e depois `validate`.

Os módulos com pasta `tests/` têm testes que rodam **sem acesso à AWS** (provider simulado):

```sh
for m in budget network alb ecs_cluster avatars database email ecr ecs_service backend_secrets; do
  terraform -chdir=modules/$m init -backend=false && terraform -chdir=modules/$m test
done
```

Cada módulo tem o próprio `.terraform.lock.hcl`, **cópia do lock da raiz**, para os testes rodarem com a mesma versão do provider do ambiente. Ao trocar a versão do provider na raiz, copie o lock novo para os módulos.

## Regras

- **Nenhum segredo** neste repositório ou em output. Segredos vão no Parameter Store (MS-28).
- `terraform apply` e `destroy` só com o plano lido e conferido.
- **Só o ambiente dev existe:** a variável `environment` só aceita `dev`, porque o backend aponta para o estado do dev. O prod vai ter estado próprio.
- O backend roda com **uma única tarefa**: o coletor fica dentro do processo e duas instâncias dobrariam as chamadas à Sungrow.
- O dev guarda dados **reais** da UFV JAC 03. Cuidado com `destroy`.
