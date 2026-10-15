# solar-monitor-infra — instruções para a IA

Infraestrutura do projeto "Monitoramento de Usinas Solares" na AWS, com Terraform. Cria o ambiente do backend (`solar-monitor`) e do frontend (`solar-monitor-web`). **Por enquanto só o ambiente dev.** **Responda sempre em português (pt-BR).**

**Leia primeiro `../docs/ONBOARDING_IA.md` e `../docs/arquitetura/09-infra-terraform-dev.md`** (decisões, serviços escolhidos e tasks MS-87 a MS-94 e MS-28 a MS-30). Os docs são a fonte de verdade e existem em duas cópias que devem ficar **iguais**: `docs/` ao lado dos repositórios e `solar-monitor-web/docs/`. Se não estiverem na sua máquina, **peça ao Ericles**.

## Regras críticas (resumo; a fonte é `docs/DIRETRIZES_DE_TRABALHO.md`)

- **Nunca execute `git commit`, `push`, `merge` nem `pull`** (nem comandos que escrevam no git). Entregue uma **mensagem de commit sugerida** no fim de cada task: `tipo(escopo): resumo (MS-XX)`.
- **Nunca rode `terraform apply`, `destroy`, `import` nem `state rm`/`mv`** sem o Ericles pedir explicitamente naquela hora: mexem em recursos reais e custam dinheiro. `fmt`, `validate`, `init`, `plan` e `test` podem.
- **Nenhum segredo** no código, em `*.tfvars` ou em output. Segredo vai no Parameter Store (o Terraform cria o parâmetro com valor provisório e `ignore_changes`; o valor real é colocado à mão) ou é gerenciado pela própria AWS (senha do RDS).
- **Uma task do Jira por vez** (projeto MS, épico MS-6). **Decisão fora dos docs = pare e pergunte.**
- O backend roda com **uma única tarefa** (o coletor fica dentro do processo). Não aumente `desired_count` do backend.

## Padrão do código (referência: [`terraform_infra`](https://github.com/Ericles-Miller/terraform_infra))

- Ambiente na **raiz**: `providers.tf` (bloco `terraform` + `provider`), `variables.tf`, `main.tf` (módulos), `datasource.tf`, `output.tf`.
- Módulos em `modules/<nome>/`: `main.tf`, `variables.tf`, `outputs.tf`, `datasource.tf` (só se tiver data source) e `tests/` (`terraform test` com `mock_provider`).
- Variáveis de módulo com o **prefixo do módulo** (`budget_name`, `rds_instance_class`...) e `<prefixo>_tags` (`map(string)`, padrão `{}`).
- Variáveis com `type`, `description` e `default`; outputs com `value`, `sensitive` e `description`. Descrições em pt-BR.
- Nomes de recurso: `solar-monitor-${var.environment}-<nome>`. Tags comuns pelas `default_tags` do provider.
- Valores fixos no `default` do `variables.tf`; `*.tfvars` fora do git. O e-mail do alerta vem de `TF_VAR_budget_alert_emails`.
- Provider com **versão exata** no `providers.tf` e `.terraform.lock.hcl` versionado.

## Como validar

- `terraform fmt -check -recursive` na raiz.
- `terraform init -backend=false` e `terraform validate` (o mesmo em `bootstrap/` com `-chdir`).
- `terraform -chdir=modules/<nome> test` nos módulos com `tests/`.
- Com credencial válida: `terraform plan` (o perfil `ericles-dev` já está no código). No shell da IA o `~/.zshrc` não é carregado: passe `TF_VAR_budget_alert_emails` na linha do comando.
