# lab-utils-notify

Reference lab for notifying developer teams every time a new release is
published in the `container-utils` repository. Zero SMTP, zero external
webhooks, zero third-party services. Uses only native GitHub primitives
(Actions + Issue + team mention + GitHub's own notification engine +
GitHub App for reliable delivery).

Target audience: a **junior analyst** who needs to understand, test, and
replicate this setup in the bank's `container-utils` repository.

---

## 1. What this lab delivers

**Two workflow files** (single template, single caller):

- `.github/workflows/notify-release-images.yml` (caller, 40 lines): only
  the trigger config + the recipient team list.
- `.github/workflows/notify-release-images-template.yml` (reusable
  template, ~250 lines self-contained): checkout, App token generation,
  tag resolution, catalog + diff bash inline, Issue creation via
  `github-script` with the App token.

Client edits **two things** in the caller:

1. `workflows: ["Release"]` -- name of upstream release workflow
2. `teams:` -- recipient teams (@ORG/team only, bare @user is rejected)

The template does everything else. No external scripts, no `scripts/`
directory. The Issue's `@ORG/team` mentions trigger GitHub's native
notification engine -- GitHub delivers the email, we do not.

Example of what a developer receives:

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

---

## 2. GitHub App (REQUIRED)

The template **requires** a GitHub App to send the Issue with a token
that has `Members: Read`. The default `GITHUB_TOKEN` cannot reliably
resolve team members for mention notifications, so we do not use it.

### 2.1. Create the App

1. Navigate to `https://github.com/organizations/<YOUR-ORG>/settings/apps/new`
2. Name: `container-utils-notify` (or similar)
3. Homepage URL: any placeholder
4. Webhook: uncheck "Active"
5. **Repository permissions**:
   - `Contents`: Read-only
   - `Issues`: Read and write
6. **Organization permissions**:
   - `Members`: Read-only
7. Where can this GitHub App be installed? "Only on this account"
8. Create the App
9. Note the **Client ID** shown on the App settings page
10. Generate a private key: scroll down, click "Generate a private key",
    a `.pem` file is downloaded

### 2.2. Install the App on the repo

- On the App settings page, click "Install App" in the left sidebar
- Choose the org, select "Only select repositories", pick `container-utils`
- Install

### 2.3. Configure the repo

- **Repository variable** `NOTIFY_APP_CLIENT_ID`:
  Settings -> Secrets and variables -> Actions -> Variables tab -> New
  variable. Paste the App's Client ID.
- **Repository secret** `NOTIFY_APP_PRIVATE_KEY`:
  Settings -> Secrets and variables -> Actions -> Secrets tab -> New
  repository secret. Paste the **full contents** of the `.pem` file
  (including `-----BEGIN...` and `-----END...` lines).

Both can also be defined at the **organization level** so multiple repos
share the same App -- see GitHub docs for org-level vars/secrets.

### 2.4. Verify

Once the vars/secrets exist, trigger `workflow_dispatch` and confirm:

- The step `Generate GitHub App token` succeeds
- The Issue is created and the `@ORG/team` mentions render as clickable
  links (not plain text)
- Team members receive the GitHub email from `notifications@github.com`

If mentions render as plain text, the App is missing `Members: Read` or
was not installed on the repo.

---

## 3. Teams

Every team referenced in `teams:` must exist in the org and have members:

```bash
gh api orgs/<ORG>/teams -f name=container-utils-consumers -f privacy=closed
gh api orgs/<ORG>/teams/container-utils-consumers/memberships/<USER> -X PUT
```

**Teams must have `privacy=closed`** for the App to resolve them. Teams
with `privacy=secret` are invisible even to Apps with `Members: Read`.

Only `@ORG/team` format is accepted. Bare `@user` mentions are rejected
by the template. This enforces that notifications go through teams
(auditable, maintainable), not to individuals hardcoded in a workflow.

---

## 4. Trigger strategy

The caller triggers on **`workflow_run`**:

```yaml
on:
  workflow_run:
    workflows: ["Release"]         # <-- upstream workflow name
    types: [completed]
    branches: [main]
```

Fires whenever the client's release-creating workflow finishes on `main`.
Works even when the upstream uses the default `GITHUB_TOKEN` (which by
design does NOT fire `release: published` in downstream workflows --
GitHub's built-in loop protection).

For manual testing, `workflow_dispatch` is also wired with a `tag` input.

---

## 5. Testing (before promoting to `container-utils`)

### 5.1. Push this lab to the org (or a personal account for lab-only)

```bash
gh repo create <ORG>/lab-utils-notify --source=. --push --private
```

### 5.2. Configure the App vars/secrets (section 2)

### 5.3. Point `teams:` at a test team with 2-3 volunteer members

Edit `.github/workflows/notify-release-images.yml`, replace `teams:` with:

```yaml
teams: |
  @<ORG>/lab-notify-test
```

### 5.4. Fire the manual test

```bash
gh workflow run notify-release-images.yml -f tag=v0.0.0-test
```

### 5.5. Verify

- Actions tab: green run, step summary shows the catalog
- Issues tab: new Issue with label `release-notification`
- Each volunteer confirms receipt of the GitHub email in their inbox

See `VALIDATION.md` for the full protocol.

---

## 6. Promoting to `container-utils`

Once section 5 passes with real team members confirming email receipt:

1. Copy both workflow files to `container-utils/.github/workflows/`
2. In the caller, set `workflows: ["<upstream-workflow-name>"]` and
   `teams:` with the real consumer teams
3. Configure `NOTIFY_APP_CLIENT_ID` (var) and `NOTIFY_APP_PRIVATE_KEY`
   (secret) on `container-utils` -- or use org-level values
4. Ensure the App is installed on `container-utils`
5. Open PR, review, merge
6. Manually dispatch `-f tag=v0.0.0-prod-test` to smoke-test
7. Confirm one member per team received the email

---

## 7. Adding / removing recipient teams

Edit `teams:` in `notify-release-images.yml`. One per line, `@ORG/team`
format only. PR, review, merge. Next release uses the new list.

Best practice: add a `CODEOWNERS` rule requiring platform-team approval
for changes to `.github/workflows/notify-release-images.yml`.

---

## 8. Troubleshooting

| Symptom | Likely cause | Resolution |
|---|---|---|
| Step `Generate GitHub App token` fails | Missing vars/secrets, or App not installed on repo | Section 2 |
| Issue created but no email | Team has `privacy=secret` | `gh api -X PATCH orgs/<ORG>/teams/<team> -f privacy=closed` |
| Team mention renders as plain text | App lacks `Members: Read` | Recreate/update the App |
| One dev did not receive | That dev disabled `@mention` email | They check `settings/notifications` |
| Catalog table is empty | No `Dockerfile*` in the repo | Verify the expected files exist |
| `Could not resolve a release tag` | No release exists yet | Publish one, or pass `-f tag=...` in manual dispatch |
| `Invalid tag format` | Tag has characters outside `[a-zA-Z0-9._+-]` | Rename the tag |
| `has no valid @ORG/team mentions` | `teams:` contains bare `@user` | Use `@ORG/team` format only |
| workflow_run does not fire | Upstream workflow name mismatch | Check `workflows: ["<name>"]` matches upstream `name:` |

---

## 9. Files in this lab

```
.
|-- README.md                                          this file
|-- flow.md                                            event-flow explanation + diagram
|-- VALIDATION.md                                      delivery-validation protocol
|-- claude.md                                          original challenge brief
|-- .github/
|   `-- workflows/
|       |-- notify-release-images.yml                  caller (40 lines, client-editable)
|       `-- notify-release-images-template.yml         reusable template (self-contained)
|-- microservices-deployment-openjdk21/Dockerfile      multi-stage OpenJDK
|-- python-deployment-3.12-slim/Dockerfile             single-stage Python
`-- react-deployment-nginx-with-envs/Dockerfile        multi-stage Node + nginx
```

No `scripts/` directory: all bash is inline in the template's `run:` steps.

---

## 10. References

- Team mentions: https://docs.github.com/en/organizations/organizing-members-into-teams/setting-your-team-page
- Reusable workflows: https://docs.github.com/en/actions/using-workflows/reusing-workflows
- `workflow_run` trigger: https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_run
- `actions/create-github-app-token@v3`: https://github.com/actions/create-github-app-token
- `actions/github-script`: https://github.com/actions/github-script
