# solar-monitor-infra — instruções para a IA

Infraestrutura do projeto "Monitoramento de Usinas Solares" na AWS, com Terraform. Cria o ambiente do backend (`solar-monitor`) e do frontend (`solar-monitor-web`). **Por enquanto só o ambiente dev.** **Responda sempre em português (pt-BR).**

**Leia primeiro `../docs/ONBOARDING_IA.md` e `../docs/arquitetura/09-infra-terraform-dev.md`** (decisões, serviços escolhidos e tasks MS-87 a MS-94 e MS-28 a MS-30). Os docs são a fonte de verdade e existem em duas cópias que devem ficar **iguais**: `docs/` ao lado dos repositórios e `solar-monitor-web/docs/`. Se não estiverem na sua máquina, **peça ao Ericles**.

## Regras críticas (resumo; a fonte é `docs/DIRETRIZES_DE_TRABALHO.md`)

- **Nunca execute `git commit`, `push`, `merge` nem `pull`** (nem comandos que escrevam no git). Entregue uma **mensagem de commit sugerida** no fim de cada task: `tipo(escopo): resumo (MS-XX)`.
- **Nunca rode `terraform apply`, `destroy`, `import` nem `state rm`/`mv`** sem o Ericles pedir explicitamente naquela hora: mexem em recursos reais e custam dinheiro. `fmt`, `validate`, `init` e `plan` podem.
- **Nenhum segredo** no código, em `terraform.tfvars` ou em output. Segredo vai no Parameter Store (o Terraform cria o parâmetro com valor provisório e `ignore_changes`; o valor real é colocado à mão) ou é gerenciado pela própria AWS (senha do RDS).
- **Uma task do Jira por vez** (projeto MS, épico MS-6). **Decisão fora dos docs = pare e pergunte.**
- O backend roda com **uma única tarefa** (o coletor fica dentro do processo). Não aumente `desired_count` do backend.

## Como validar

- `terraform fmt -check -recursive` na raiz.
- `terraform -chdir=envs/dev init -backend=false` e `terraform -chdir=envs/dev validate` (o mesmo para `bootstrap/`).
- Com credencial válida (`AWS_PROFILE=ericles-dev`): `terraform -chdir=envs/dev plan`.
