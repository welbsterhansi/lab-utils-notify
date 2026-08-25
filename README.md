# lab-utils-notify

Lab de referencia para notificar times de desenvolvedores sempre que houver
uma nova release no repositorio `container-utils`. Zero dependencia de SMTP,
webhook externo ou servico de terceiros. Usa apenas primitivas nativas do
GitHub (Actions + Issue + team mention + motor de notificacao do proprio
GitHub).

Publico alvo: **analista junior** que precisa entender, testar e replicar
este setup no repo `container-utils` da org do banco.

---

## 1. O que este lab entrega

- **Um workflow pronto** (`.github/workflows/notify-release-images.yml`) que:
  1. Dispara em toda `release: published` (e permite teste manual)
  2. Varre todos os `Dockerfile*` do repo
  3. Extrai a imagem final (`FROM`) e separa em colunas `Imagem`, `Tag`, `Digest`
  4. Calcula o **diff contra a release anterior** (o que mudou de tag)
  5. Abre uma Issue mencionando os times consumidores com as duas tabelas
  6. GitHub envia e-mail nativo para cada membro dos times

  Exemplo do que o dev recebe no corpo da Issue:

  > ## Catalogo de imagens base (release `v1.5.0`)
  >
  > | Stack | Imagem | Tag | Digest |
  > |---|---|---|---|
  > | `python-deployment-3.12-slim` | `python` | `3.12-slim-bookworm` | `sha256:3c4d5e...a1b2` |
  >
  > ## Mudancas desde `v1.4.0`
  >
  > | Stack | Tag anterior | Tag atual | Mudou? |
  > |---|---|---|---|
  > | `python-deployment-3.12-slim` | `3.12-slim` | `3.12-slim-bookworm` | **SIM** |
  > | `microservices-deployment-openjdk21` | `1.20-2.1727869871` | `1.20-2.1727869871` | sem mudanca |

  Dockerfiles do `container-utils` fixam a imagem final com `tag@sha256:...`
  (imutabilidade em prod). O workflow le e emite as tres partes separadas.

  A segunda tabela responde a pergunta pratica: **"preciso rebuildar?"**.

- **Dockerfiles de exemplo na raiz** (`microservices-deployment-openjdk21/`,
  `python-deployment-3.12-slim/`, `react-deployment-nginx-with-envs/`) que
  reproduzem a mesma estrutura do `container-utils` real. Servem para testar
  o workflow neste repo antes de promover pro repo de producao.

- **Documentacao** para o fluxo (`fluxo.md`) e o protocolo de validacao
  (`VALIDACAO.md`).

---

## 2. Pre-requisitos na org do banco

Coisas que precisam existir **antes** do workflow rodar. Estas sao tarefas
de administracao de org, feitas uma unica vez.

### 2.1. Teams existentes

Cada team mencionado no workflow precisa existir na org:

- `@welbsterhansi/container-utils-consumers` (team guarda-chuva, opcional)
- `@welbsterhansi/dev-team-pagamentos`
- `@welbsterhansi/dev-team-cartoes`
- (adicione outros conforme necessario)

Como criar (via UI):
`https://github.com/orgs/welbsterhansi/new-team`

Como criar (via CLI, precisa `admin:org` no PAT):
```bash
gh api orgs/welbsterhansi/teams -f name=dev-team-pagamentos -f privacy=closed
gh api orgs/welbsterhansi/teams/dev-team-pagamentos/memberships/USUARIO -X PUT
```

### 2.2. GitHub App para notificacao confiavel (recomendado em prod)

Motivo: o `GITHUB_TOKEN` padrao (`github-actions[bot]`) **nao dispara e-mail
confiavel** em team mentions. Uma GitHub App dedicada resolve.

Passos:
1. Criar GitHub App em `https://github.com/organizations/welbsterhansi/settings/apps/new`
   - Permissoes: `Issues: Read & write`, `Members: Read`, `Contents: Read`
   - Sem webhook, sem callback URL
2. Instalar a App no repo `container-utils`
3. Gerar Private Key, baixar o `.pem`
4. No repo `container-utils`, cadastrar dois secrets:
   - `NOTIFY_APP_ID` (App ID numerico)
   - `NOTIFY_APP_PRIVATE_KEY` (conteudo do `.pem`)
5. Descomentar o step "Gera token da GitHub App" no workflow e trocar
   `github-token:` para usar `${{ steps.app-token.outputs.token }}`.

**Sem a App, o workflow ainda cria a Issue, mas o e-mail pode nao chegar.**
Nao promova para producao sem validar a entrega (ver `VALIDACAO.md`).

---

## 3. Como testar neste lab (sem tocar em `container-utils`)

O objetivo aqui e validar que o workflow **funciona** antes de promove-lo.

### 3.1. Fork ou push deste lab para a org

```bash
gh repo create welbsterhansi/lab-utils-notify --source=. --push --private
```

### 3.2. Editar a lista de teams no workflow

Abra `.github/workflows/notify-release-images.yml` e ajuste `env.TEAMS`
para conter **apenas um team de teste** com voces mesmos como membros:

```yaml
env:
  TEAMS: |
    @welbsterhansi/lab-notify-test
```

Crie o team `lab-notify-test` na org e adicione 2-3 devs voluntarios.

### 3.3. Disparar teste manual

```bash
gh workflow run notify-release-images.yml -f tag=v0.0.0-test
```

Ou pela UI: **Actions -> Notify release base images -> Run workflow**.

### 3.4. Verificar

- Aba **Actions**: run verde, step summary mostra o catalogo de imagens
- Aba **Issues**: Issue nova com label `release-notification`
- **Cada membro do team `lab-notify-test`**: e-mail do GitHub na inbox

**Se o e-mail nao chegou:** ver secao Troubleshooting.

---

## 4. Como promover para `container-utils`

Depois que o teste no lab passar:

1. Copiar `.github/workflows/notify-release-images.yml` para o mesmo path
   no repo `container-utils`.
2. Editar `env.TEAMS` com a lista real de times consumidores.
3. Configurar os secrets `NOTIFY_APP_ID` e `NOTIFY_APP_PRIVATE_KEY` no repo
   `container-utils` (ver secao 2.2).
4. Descomentar o step da GitHub App e o `github-token:` em `github-script`.
5. Fazer PR, mergear.
6. Publicar uma release de teste (ou usar `workflow_dispatch`) e validar
   entrega pelo protocolo em `VALIDACAO.md`.

---

## 5. Como adicionar/remover times destinatarios

Editar `env.TEAMS` no proprio workflow, um team por linha:

```yaml
env:
  TEAMS: |
    @welbsterhansi/dev-team-pagamentos
    @welbsterhansi/dev-team-cartoes
    @welbsterhansi/dev-team-pix        # <-- novo time
```

PR, review, merge. Proximo release ja usa a nova lista.

Boa pratica: adicionar regra em `CODEOWNERS` exigindo aprovacao do time de
plataforma para mudancas em `.github/workflows/notify-release-images.yml`.

---

## 6. Troubleshooting

| Sintoma | Causa provavel | Como resolver |
|---|---|---|
| Workflow roda, Issue nao aparece | Sem `permissions: issues: write` | Ja esta no template, verificar se nao foi removido |
| Issue aparece, e-mail nao chega | Usando `GITHUB_TOKEN`, nao a App | Configurar GitHub App (secao 2.2) |
| Um dev nao recebeu, outros sim | Dev desativou notificacao de mention | Dev checa em `settings/notifications` |
| Tabela de imagens vazia | Nao ha `Dockerfile*` no repo | Verificar que o repo tem os arquivos esperados |
| `Discussion category not found` | Voce copiou versao antiga (Discussion) | Usar este template (Issue), nao o de Discussion |
| `Nenhum team configurado em env.TEAMS` | Bloco `TEAMS` vazio ou sem `@` | Adicionar teams com prefixo `@welbsterhansi/` |

Para trace completo: aba **Actions -> run com falha -> log do job**.

---

## 7. Arquivos deste lab

```
.
|-- README.md                                     este arquivo
|-- fluxo.md                                      diagrama e explicacao do fluxo
|-- VALIDACAO.md                                  protocolo de validacao de entrega
|-- .github/
|   `-- workflows/
|       `-- notify-release-images.yml             o workflow
|-- microservices-deployment-openjdk21/
|   `-- Dockerfile                                exemplo multi-stage (OpenJDK)
|-- python-deployment-3.12-slim/
|   `-- Dockerfile                                exemplo single-stage (Python)
`-- react-deployment-nginx-with-envs/
    `-- Dockerfile                                exemplo multi-stage (Node + nginx)
```

Estrutura espelha container-utils: cada stack tem seu diretorio na raiz
com um Dockerfile dentro. E o que o workflow procura (find `Dockerfile*`).

---

## 8. Referencias

- Docs oficiais de team mentions: https://docs.github.com/en/organizations/organizing-members-into-teams/setting-your-team-page
- Docs `actions/github-script`: https://github.com/actions/github-script
- Docs `actions/create-github-app-token`: https://github.com/actions/create-github-app-token
- Security hardening para GitHub Actions: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions
