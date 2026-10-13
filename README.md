# solar-monitor-infra

Infraestrutura do **Solar Monitor** (monitoramento de usinas solares) na AWS, com Terraform. Um único projeto cria o ambiente do backend ([`solar-monitor`](../solar-monitor)) e do frontend ([`solar-monitor-web`](../solar-monitor-web)).

**Por enquanto só existe o ambiente `dev`**, na região `sa-east-1` (São Paulo). Decisões, serviços escolhidos e o motivo de cada um: `docs/arquitetura/09-infra-terraform-dev.md`.

## Estrutura

| Pasta | O que é |
|---|---|
| `bootstrap/` | Cria o bucket S3 que guarda o estado do Terraform. Roda **uma vez por conta**, com estado local |
| `envs/dev/` | O ambiente dev. Usa os módulos e guarda o estado no bucket do bootstrap |
| `modules/` | Um módulo por bloco de infraestrutura |

Módulos de hoje:

| Módulo | Task | O que cria |
|---|---|---|
| `budget` | MS-87 | Orçamento mensal com alerta de custo por e-mail |

Os próximos entram com as tasks do épico MS-6: rede, ALB e cluster ECS (MS-88), banco RDS (MS-89), bucket dos avatares (MS-90), SES (MS-91), backend (MS-28) e frontend (MS-29) no ECS, scripts de deploy (MS-94) e domínio com HTTPS (MS-30).

## Pré-requisitos

- **Terraform >= 1.10** (a trava do estado usa o lockfile nativo do S3).
- **AWS CLI v2** com o perfil **`ericles-dev`** configurado e com permissão para criar os recursos.
- Em todo terminal que for rodar Terraform:

  ```sh
  export AWS_PROFILE=ericles-dev
  aws sts get-caller-identity   # confere a conta antes de qualquer plan
  ```

Nenhuma credencial fica no código: o Terraform usa o perfil da variável `AWS_PROFILE`.

## Primeira vez numa conta

### 1. Bucket do estado (bootstrap)

```sh
terraform -chdir=bootstrap init
terraform -chdir=bootstrap apply
```

Cria `solar-monitor-tfstate-<id-da-conta>`: versionado, criptografado, sem acesso público e só por HTTPS. O estado do bootstrap fica local (`bootstrap/terraform.tfstate`, fora do git). Se ele se perder, o bucket continua lá; para administrá-lo de novo, use `terraform import`.

### 2. Apontar o dev para o bucket

```sh
echo "bucket = \"$(terraform -chdir=bootstrap output -raw state_bucket)\"" > envs/dev/backend.hcl
```

Versione o `envs/dev/backend.hcl`: ele só tem o nome do bucket, que não é segredo.

### 3. Preencher os valores do dev

Quem recebe os alertas de custo **não fica no repositório**: vem da variável de ambiente `TF_VAR_budget_alert_emails`, uma lista em formato HCL. Coloque no seu `~/.zshrc` (ou equivalente):

```sh
export TF_VAR_budget_alert_emails='["voce@exemplo.com"]'
```

- **Não** defina `budget_alert_emails` no `terraform.tfvars`: o arquivo tem prioridade sobre o ambiente e esconderia o valor exportado.
- Sem a variável, o `plan` pergunta o valor (ou para com erro, com `-input=false`). Lista vazia ou e-mail inválido param com "Informe ao menos um e-mail válido".
- Para trocar quem recebe, mude a variável e rode `plan` + `apply`: a assinatura só muda na AWS depois do `apply`. Quem rodar o `apply` com outro valor troca os destinatários.
- O e-mail fica gravado no estado (no S3), não no git.

### 4. Liberar o custo na conta de gerenciamento (manual, uma vez)

A conta do dev (`779257801295`) é **membro de uma AWS Organization**. Orçamentos, Cost Explorer e tags de custo são controlados pela **conta de gerenciamento** (a pagadora, `471112556317`). Sem a liberação abaixo, o `apply` do orçamento falha com `AccessDeniedException: Account ... is a linked account`.

Logado na **conta de gerenciamento** (não na do dev):

1. **Billing and Cost Management** → **Cost Explorer**: abra uma vez para ativá-lo.
2. **Billing and Cost Management** → **Cost Management preferences** → **Linked account access**: dê às contas-membro acesso ao Cost Explorer e aos orçamentos.
3. **Billing and Cost Management** → **Cost allocation tags** → **User-defined cost allocation tags**: marque **`Project`** e clique em **Activate**.

O alerta de custo conta só os recursos com a tag `Project = solar-monitor`, para não misturar com outros projetos. A tag só aparece na lista do passo 3 depois que a AWS processa a cobrança de algum recurso com ela (até 24 h), e a ativação pode levar mais 24 h para valer. **Até lá, o orçamento mostra custo zero e não alerta.**

Para conferir a liberação, na conta do dev: `aws budgets describe-budgets --account-id <id-da-conta-dev>` não pode responder `AccessDeniedException`.

### 5. Subir o dev

```sh
terraform -chdir=envs/dev init -backend-config=backend.hcl
terraform -chdir=envs/dev plan -out=dev.tfplan
terraform -chdir=envs/dev apply dev.tfplan
```

Leia o `plan` antes de aplicar. O `apply` cria recursos reais e cobrados.

## Dia a dia

```sh
terraform fmt -recursive                                   # formatar
terraform -chdir=envs/dev validate                         # validar
terraform -chdir=envs/dev plan                             # ver o que vai mudar
```

Sem acesso à AWS ainda dá para validar: `terraform -chdir=envs/dev init -backend=false` e depois `validate`.

Os módulos com pasta `tests/` têm testes que rodam **sem acesso à AWS** (provider simulado):

```sh
terraform -chdir=modules/budget init
terraform -chdir=modules/budget test
```

## Regras

- **Nenhum segredo** neste repositório, em `terraform.tfvars` ou em output. Segredos vão no Parameter Store (MS-28).
- `terraform apply` e `destroy` só com o plano lido e conferido.
- O backend roda com **uma única tarefa**: o coletor fica dentro do processo e duas instâncias dobrariam as chamadas à Sungrow.
- O dev guarda dados **reais** da UFV JAC 03. Cuidado com `destroy`.
