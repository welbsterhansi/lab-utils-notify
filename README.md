# lab-utils-notify

Reference lab for notifying developer teams every time a new release is
published in the `container-utils` repository. Zero SMTP, zero external
webhooks, zero third-party services. Uses only native GitHub primitives
(Actions + Issue + team mention + GitHub's own notification engine).

Target audience: a **junior analyst** who needs to understand, test, and
replicate this setup in the bank's `container-utils` repository.

---

## 1. What this lab delivers

- **A reusable workflow template** (`.github/workflows/notify-release-images-template.yml`)
  and a **thin caller** (`.github/workflows/notify-release-images.yml`) that:
  1. Trigger AFTER the client's release-creating workflow completes on `main`
     (via `workflow_run`), and additionally allow manual test via `workflow_dispatch`.
  2. Walk every `Dockerfile*` in the repo.
  3. Extract the final image (`FROM`) and split it into `Image`, `Tag`, `Digest` columns.
  4. Compute the **diff against the previous release** (what tag/digest moved).
  5. Open an Issue mentioning the recipient teams with both tables and a UTC timestamp.
  6. GitHub delivers an email natively to every member of each team.

  Example of what a developer receives in the Issue body:

  > **New release published in `welbsterhansi/container-utils`: `v1.5.0`**
  >
  > Published at: **2026-08-25 14:32 UTC**
  > Release notes: https://github.com/welbsterhansi/container-utils/releases/tag/v1.5.0
  >
  > > This automated notification lists every base container image shipped in this release.
  > > The **Catalog** table shows each stack with its image reference, tag, and pinned digest.
  > > The **Changes since** table highlights what moved compared to the previous release --
  > > use it to decide whether your service needs to be rebuilt.
  >
  > ## Catalog of base images (release `v1.5.0`)
  >
  > | Stack | Image | Tag | Digest |
  > |---|---|---|---|
  > | `python-deployment-3.12-slim` | `python` | `3.13-slim-bookworm` | `sha256:9f0e8d...` |
  >
  > ## Changes since `v1.4.0` (for release `v1.5.0`)
  >
  > | Stack | Previous tag | Current tag | Changed? |
  > |---|---|---|---|
  > | `python-deployment-3.12-slim` | `3.12-slim-bookworm` | `3.13-slim-bookworm` | **YES** |

  The `Changes since` table answers the practical question: **"do I need to rebuild?"**.

- **Example Dockerfiles at the repo root** (`microservices-deployment-openjdk21/`,
  `python-deployment-3.12-slim/`, `react-deployment-nginx-with-envs/`) mirroring the
  real `container-utils` layout. They exist so you can test the workflow here before
  promoting to production.

- **Documentation**: this README plus `flow.md` (event flow) and `VALIDATION.md`
  (delivery-validation protocol).

---

## 2. Prerequisites in the bank's org

Things that must exist **before** the workflow runs. One-time org admin tasks.

### 2.1. Teams

Every team mentioned in the workflow must exist in the org:

- `@welbsterhansi/container-utils-consumers` (umbrella team, optional)
- `@welbsterhansi/dev-team-pagamentos`
- `@welbsterhansi/dev-team-cartoes`
- (add more as needed)

Create via UI: `https://github.com/orgs/welbsterhansi/new-team`

Create via CLI (requires `admin:org` on the PAT):

```bash
gh api orgs/welbsterhansi/teams -f name=dev-team-pagamentos -f privacy=closed
gh api orgs/welbsterhansi/teams/dev-team-pagamentos/memberships/USER -X PUT
```

### 2.2. GitHub App for reliable notification (recommended in production)

Why: the default `GITHUB_TOKEN` (`github-actions[bot]`) **does not reliably
trigger email notifications** for team mentions. A dedicated GitHub App fixes it.

Steps:

1. Create the App at `https://github.com/organizations/welbsterhansi/settings/apps/new`
   - Permissions: `Issues: Read & write`, `Members: Read`, `Contents: Read`
   - No webhook, no callback URL
2. Install the App on the `container-utils` repo
3. Generate a Private Key, download the `.pem`
4. On the `container-utils` repo, add two secrets:
   - `NOTIFY_APP_ID` (numeric App ID)
   - `NOTIFY_APP_PRIVATE_KEY` (contents of `.pem`)
5. In the template, uncomment the `create-github-app-token` step and switch
   `github-token:` to `${{ steps.app-token.outputs.token }}` (already scaffolded).

**Without the App, the Issue is still created but the email may not arrive.**
Do not promote to production without running `VALIDATION.md`.

---

## 3. Trigger strategy

The caller (`notify-release-images.yml`) triggers on **`workflow_run`**:

```yaml
on:
  workflow_run:
    workflows: ["Release"]         # <-- name of client's release workflow
    types: [completed]
    branches: [main]
```

This fires whenever the client's release-creating workflow finishes on `main`.
It works even when the client's release workflow uses the default `GITHUB_TOKEN`
(which by design does NOT fire `release: published` in downstream workflows --
GitHub's built-in loop protection).

For manual testing, `workflow_dispatch` is also wired with a `tag` input.

To switch to the plain `release: published` trigger (works only if the client
uses a PAT or GitHub App token to create releases), swap the `on:` block:

```yaml
on:
  release:
    types: [published]
```

---

## 4. Testing this lab (without touching `container-utils`)

Goal: prove the workflow works before promoting it.

### 4.1. Fork or push this lab to the org

```bash
gh repo create welbsterhansi/lab-utils-notify --source=. --push --private
```

### 4.2. Adjust the recipients

Open `.github/workflows/notify-release-images.yml` and set `teams` to just a
test team with 2-3 volunteer developers:

```yaml
with:
  teams: |
    @welbsterhansi/lab-notify-test
```

### 4.3. Fire the manual test

```bash
gh workflow run notify-release-images.yml -f tag=v0.0.0-test
```

Or via UI: **Actions -> Notify release base images -> Run workflow**.

### 4.4. Verify

- **Actions** tab: run is green, step summary shows the catalog
- **Issues** tab: new Issue with label `release-notification`
- **Each volunteer**: GitHub email in their inbox

If email does not arrive, see the Troubleshooting section.

---

## 5. Promoting to `container-utils`

Once the lab test passes:

1. Copy both workflows from `.github/workflows/` to the same path in `container-utils`.
2. Copy the entire `scripts/notify/` directory to `container-utils`.
3. In the caller, adjust `workflows: ["Release"]` to match the exact name of the
   client's release workflow, and set `teams:` to the real consumer teams.
4. Configure `NOTIFY_APP_ID` and `NOTIFY_APP_PRIVATE_KEY` secrets (section 2.2).
5. Uncomment the GitHub App token step in the template.
6. Open PR, review, merge.
7. Trigger `workflow_dispatch` with `tag=v0.0.0-prod-test` to smoke-test.
8. Follow `VALIDATION.md` phases 1-5 with real teams before considering it done.

---

## 6. Adding / removing recipient teams

Edit `teams:` in `notify-release-images.yml`, one per line:

```yaml
with:
  teams: |
    @welbsterhansi/dev-team-pagamentos
    @welbsterhansi/dev-team-cartoes
    @welbsterhansi/dev-team-pix        # <-- new team
```

PR, review, merge. The next release uses the new list.

Best practice: add a `CODEOWNERS` rule requiring platform-team approval for
changes to `.github/workflows/notify-release-images.yml`.

---

## 7. Troubleshooting

| Symptom | Likely cause | Resolution |
|---|---|---|
| Workflow runs, Issue does not appear | `permissions: issues: write` missing | Already declared in template; verify not stripped |
| Issue appears, email does not arrive | Using `GITHUB_TOKEN`, not GitHub App | Configure the App (section 2.2) |
| One developer did not receive, others did | That dev disabled mention notifications | They check `settings/notifications` |
| Catalog table is empty | No `Dockerfile*` in the repo | Verify the expected files exist |
| `Could not resolve a release tag...` | No release exists yet | Publish a release first, or pass `-f tag=...` in manual dispatch |
| `Invalid tag format: ...` | Tag contains characters outside `[a-zA-Z0-9._+-]` | Rename the tag |
| workflow_run does not fire | Upstream workflow name mismatch | Check `workflows: ["<name>"]` matches the exact `name:` field of the upstream workflow |

Full logs: **Actions -> failed run -> job log**.

---

## 8. Files in this lab

```
.
|-- README.md                                          this file
|-- flow.md                                            event-flow explanation + diagram
|-- VALIDATION.md                                      delivery-validation protocol
|-- claude.md                                          original challenge brief
|-- .github/
|   `-- workflows/
|       |-- notify-release-images.yml                  caller (thin, 55 lines)
|       `-- notify-release-images-template.yml         reusable template (workflow_call)
|-- scripts/
|   `-- notify/
|       |-- lib.sh                                     pure helpers (parse, list, resolve)
|       `-- build-catalog.sh                           orchestration (catalog + diff)
|-- microservices-deployment-openjdk21/
|   `-- Dockerfile                                     multi-stage OpenJDK
|-- python-deployment-3.12-slim/
|   `-- Dockerfile                                     single-stage Python
`-- react-deployment-nginx-with-envs/
    `-- Dockerfile                                     multi-stage Node + nginx
```

Each stack sits in its own top-level directory with a `Dockerfile` inside,
mirroring container-utils.

---

## 9. References

- Team mentions: https://docs.github.com/en/organizations/organizing-members-into-teams/setting-your-team-page
- Reusable workflows: https://docs.github.com/en/actions/using-workflows/reusing-workflows
- `workflow_run` trigger: https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_run
- `actions/github-script`: https://github.com/actions/github-script
- `actions/create-github-app-token`: https://github.com/actions/create-github-app-token
- Actions security hardening: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions
