# Validation protocol

How to prove, with evidence, that **team members actually receive the
notification email**. Do not promote to production without running this
end-to-end.

Audience: the junior analyst running the test. Every step must be
executed **exactly** as written and every piece of evidence saved.

---

## Prerequisites

- Admin access to the lab repo to configure Actions and read Issues.
- Org admin access (or a colleague with it) to create the GitHub App and
  the test team.
- 2-3 volunteer developers with GitHub accounts and time to confirm
  email receipt within 30 minutes.

---

## Phase 1 - Setup

### 1.1. Create the test team

```bash
gh api orgs/<ORG>/teams -f name=lab-notify-test -f privacy=closed
```

**`privacy=closed` is mandatory** -- teams with `privacy=secret` are
invisible to Apps even with `Members: Read`.

Add the volunteers as members:

```bash
gh api orgs/<ORG>/teams/lab-notify-test/memberships/<USER> -X PUT
```

Wait until every volunteer accepts the invitation email before
continuing.

**Evidence 1**: screenshot of the team page showing all N members.

### 1.2. Confirm each volunteer's notification preferences

Each volunteer opens `https://github.com/settings/notifications` and
confirms:

- [ ] "Participating and @mentions" has **Email** checked
- [ ] Primary/preferred email is verified

If any is missing, that volunteer's test will fail for a reason outside
the workflow.

**Evidence 2**: screenshot from each volunteer.

### 1.3. Create and install the GitHub App

Follow README section 2 in full. Verify:

- [ ] App created with permissions: `Contents: Read`, `Issues: R&W`, `Members: Read`
- [ ] App installed on the `lab-utils-notify` repo
- [ ] `secrets.NOTIFY_APP_ID` set on the repo (or org)
- [ ] `secrets.NOTIFY_APP_PRIVATE_KEY` set on the repo (or org)

**Evidence 3**: screenshots of the secrets page (values redacted).

### 1.4. Push the lab and point at the test team

```bash
cd lab-utils-notify
gh repo create <ORG>/lab-utils-notify --source=. --push --private
```

Edit `.github/workflows/notify-release-images.yml`:

```yaml
with:
  teams: |
    @<ORG>/lab-notify-test
```

Commit and push.

---

## Phase 2 - Fire the test

### 2.1. Trigger

```bash
gh workflow run notify-release-images.yml -f tag=v0.0.0-test
```

### 2.2. Wait 2 minutes and collect

- [ ] Green run in **Actions**. **Evidence 4**: link to the run.
- [ ] Step `Generate GitHub App token` succeeded (no errors in log).
- [ ] Issue created in **Issues** with label `release-notification` and
      closed as completed.
      **Evidence 5**: link to the Issue.
- [ ] In the Issue body, `@<ORG>/lab-notify-test` renders as a
      clickable link (not plain text).
      **Evidence 6**: screenshot of the Issue body.
- [ ] Each volunteer checks their inbox and reports:
      "received email (YES/NO), time HH:MM"

Record the table:

| Volunteer | Received email? | Time |
|---|---|---|
| dev1 | ... | ... |
| dev2 | ... | ... |
| dev3 | ... | ... |

**Success criterion**: **100% of volunteers with correct preferences
receive the email**.

If any fails, go to Phase 3 before promoting.

---

## Phase 3 - Diagnosing individual failures

If a volunteer did not receive despite correct preferences:

1. **Confirm the App is installed and has `Members: Read`**

   ```bash
   gh api /orgs/<ORG>/installations
   ```

   Locate the App and check its permissions in the UI.

2. **Confirm the team is `privacy=closed`**

   ```bash
   gh api orgs/<ORG>/teams/lab-notify-test --jq '.privacy'
   ```

   If `secret`, switch:

   ```bash
   gh api -X PATCH orgs/<ORG>/teams/lab-notify-test -f privacy=closed
   ```

3. **Confirm the mention rendered as a link**

   Open the Issue. The team name should be a clickable link. Plain text
   means the App did not resolve the team -- return to step 1 or 2.

4. **Confirm the corporate email filter**

   Email from `notifications@github.com` may be caught by the bank's
   Exchange spam filter. Ask the volunteer to search for
   `from:notifications@github.com` in their client.

5. **Confirm the token used**

   In the run log, the step `Create announcement Issue` should show
   authentication via the App token. If it shows `github-actions[bot]`,
   the App token step failed silently.

---

## Phase 4 - Promotion to production

Only after Phase 2 passes 100%:

- [ ] Copy both workflow files to `container-utils/.github/workflows/`
- [ ] Rename `workflows: ["Release"]` to match the client's release workflow
- [ ] Set `teams:` in the caller to the real consumer teams
- [ ] Install the App on `container-utils` (or reuse org-level installation)
- [ ] Set `NOTIFY_APP_ID` and `NOTIFY_APP_PRIVATE_KEY` on
      `container-utils` as secrets (or inherit from org)
- [ ] Open PR, review, merge
- [ ] Dispatch `-f tag=v0.0.0-prod-test` on `container-utils`
- [ ] Confirm one member from each real team received the email
- [ ] Publish a real release and observe

---

## Final report

At the end of Phase 4, deliver a document containing:

1. Timestamps of each test fire
2. Links to the runs
3. Links to the Issues created
4. Consolidated receipt table (developer, phase, result)
5. Screenshot of at least one volunteer's inbox showing the email
6. Any deviation from this protocol with justification

Without this report, the validation is not considered done.
