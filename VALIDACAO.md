# Protocolo de validacao

Como provar, com evidencia, que **outros times de fato recebem a
notificacao**. Sem este protocolo executado, nao promover para producao.

Publico: analista junior conduzindo o teste. Cada etapa deve ser feita
**exatamente** como descrita e cada evidencia salva.

---

## Pre-requisitos

- Acesso admin ao repo do lab (ou fork em conta pessoal) para configurar
  Actions e ler Issues.
- 2 ou 3 devs voluntarios com contas GitHub e disponibilidade para
  confirmar recebimento de e-mail nos proximos 30 minutos.
- Team de teste na org com esses voluntarios como membros.

---

## Fase 1 - Setup do sandbox

### 1.1. Criar team de teste

```bash
gh api orgs/welbsterhansi/teams -f name=lab-notify-test -f privacy=closed
```

Adicionar membros (repetir para cada voluntario):

```bash
gh api orgs/welbsterhansi/teams/lab-notify-test/memberships/USUARIO -X PUT
```

Cada voluntario recebe convite por e-mail. Confirmar que **todos aceitaram
o convite** antes de prosseguir. Se um voluntario nao aceitar, o teste
falha para ele por motivo alheio ao workflow.

**Evidencia 1**: screenshot da pagina do team mostrando os N membros.

### 1.2. Confirmar preferencias de notificacao de cada voluntario

Cada voluntario abre `https://github.com/settings/notifications` e confirma:

- [ ] "Participating and @mentions" marcado com **Email**
- [ ] E-mail primario/preferido esta verificado

Nao pular. Se um voluntario tem "Email" desmarcado, o teste dele falha e
nao e culpa do workflow.

**Evidencia 2**: cada voluntario envia screenshot desta pagina.

### 1.3. Push do lab para org

```bash
cd lab-utils-notify
gh repo create welbsterhansi/lab-utils-notify --source=. --push --private
```

### 1.4. Editar o workflow com o team de teste

Abrir `.github/workflows/notify-release-images.yml` e alterar:

```yaml
env:
  TEAMS: |
    @welbsterhansi/lab-notify-test
```

Commit + push.

---

## Fase 2 - Teste com `GITHUB_TOKEN` (baseline)

Objetivo: confirmar que a Issue e criada, e **medir se o e-mail chega**
usando o token padrao. Provavel que nao chegue (esperado).

### 2.1. Disparar

```bash
gh workflow run notify-release-images.yml -f tag=v0.0.0-baseline
```

### 2.2. Aguardar 2 minutos e coletar

- [ ] Run verde em `Actions` **Evidencia 3**: link do run
- [ ] Issue criada em `Issues` com label `release-notification`
      **Evidencia 4**: link da issue
- [ ] Cada voluntario checa inbox e responde no chat interno:
      "recebi e-mail (SIM/NAO), horario XX:XX"

Registrar tabela:

| Voluntario | Recebeu e-mail? | Horario |
|---|---|---|
| dev1 | ... | ... |
| dev2 | ... | ... |
| dev3 | ... | ... |

**Resultado esperado**: maioria responde NAO. Isso confirma que
`GITHUB_TOKEN` nao e suficiente para notificar team members.

Se todos responderem SIM: otimo, pode ser que a org esteja com config
permissiva; ainda assim recomendo prosseguir para Fase 3 pra ter garantia.

---

## Fase 3 - Teste com GitHub App

### 3.1. Criar e instalar a App

Seguir secao 2.2 do `README.md`. Verificacoes:

- [ ] App criada com permissoes: `Issues: R&W`, `Members: Read`, `Contents: Read`
- [ ] App instalada no repo `lab-utils-notify`
- [ ] Secrets `NOTIFY_APP_ID` e `NOTIFY_APP_PRIVATE_KEY` cadastrados no repo

### 3.2. Habilitar App no workflow

No workflow, **descomentar**:

1. O step `Gera token da GitHub App`
2. A linha `github-token: ${{ steps.app-token.outputs.token }}` dentro do
   step `Cria Issue de anuncio`

Commit + push.

### 3.3. Disparar

```bash
gh workflow run notify-release-images.yml -f tag=v0.0.0-app
```

### 3.4. Aguardar 2 minutos e coletar

Mesma tabela da Fase 2, agora com resultado da Fase 3:

| Voluntario | Recebeu Fase 2 | Recebeu Fase 3 | Diferenca |
|---|---|---|---|
| dev1 | NAO | SIM | App corrigiu |
| dev2 | NAO | SIM | App corrigiu |
| dev3 | NAO | NAO | Investigar (secao 4) |

**Criterio de sucesso**: **100% dos voluntarios com preferencias corretas
recebem e-mail na Fase 3**.

Se algum dev nao recebeu apesar de ter as preferencias corretas, ver
secao 4 antes de promover para producao.

---

## Fase 4 - Diagnostico de falhas individuais

Se um voluntario nao recebeu na Fase 3:

1. **Confirmar App instalada com `Members: Read`**
   ```bash
   gh api /orgs/welbsterhansi/installations
   ```
   Procurar a App e conferir permissoes.

2. **Confirmar que o team e "visivel" para a App**
   Se o team for `secret` (privacy=secret), a App pode nao enxergar. Trocar
   para `closed`:
   ```bash
   gh api -X PATCH orgs/welbsterhansi/teams/lab-notify-test -f privacy=closed
   ```

3. **Confirmar que a mention foi processada**
   Abrir a Issue criada, procurar o nome do team - se aparecer como link
   clicavel, foi processada. Se aparecer como texto puro, nao foi.

4. **Confirmar preferencias do voluntario**
   Repetir a checagem do passo 1.2 desta doc.

5. **Confirmar filtros de e-mail corporativo**
   E-mail de `notifications@github.com` pode estar caindo em spam ou sendo
   filtrado pelo Exchange do banco. Pedir para o voluntario buscar por
   `from:notifications@github.com` no cliente de e-mail.

---

## Fase 5 - Promocao para producao

Somente apos Fase 3 passar com 100%:

- [ ] Copiar `.github/workflows/notify-release-images.yml` para
      `container-utils`
- [ ] Trocar `env.TEAMS` pela lista real de times consumidores
- [ ] Configurar secrets `NOTIFY_APP_ID` e `NOTIFY_APP_PRIVATE_KEY` no repo
      `container-utils` (mesma App)
- [ ] Fazer PR, review, merge
- [ ] Rodar `workflow_dispatch` com `tag=v0.0.0-prod-test` em
      `container-utils`
- [ ] Confirmar que **um dev de cada team real** recebeu o e-mail
      (amostra minima; se falhar, voltar para Fase 4)
- [ ] Publicar uma release real e observar

---

## Relatorio final para o chefe

Ao terminar a Fase 5, entregar um documento curto com:

1. Data e horario de cada disparo
2. Links dos runs (Fase 2, Fase 3, prod)
3. Links das Issues criadas
4. Tabela consolidada de recebimento (nome do dev, fase, resultado)
5. Screenshot da inbox de pelo menos um voluntario mostrando o e-mail
6. Qualquer desvio do protocolo com justificativa

Sem este relatorio, considerar que a validacao nao foi feita.
