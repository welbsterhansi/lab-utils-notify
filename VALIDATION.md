# Validation protocol

How to prove, with evidence, that **other teams actually receive the
notification**. Do not promote to production without running this end-to-end.

Audience: the junior analyst running the test. Every step must be executed
**exactly** as written and every piece of evidence saved.

---

## Prerequisites

- Admin access to the lab repo (or a fork in a personal account) to configure
  Actions and read Issues.
- 2-3 volunteer developers with GitHub accounts and time to confirm email
  receipt in the next 30 minutes.
- A test team in the org containing those volunteers as members.

---

## Phase 1 - Sandbox setup

### 1.1. Create the test team

```bash
gh api orgs/welbsterhansi/teams -f name=lab-notify-test -f privacy=closed
```

Add members (repeat for each volunteer):

```bash
gh api orgs/welbsterhansi/teams/lab-notify-test/memberships/USER -X PUT
```

Each volunteer receives an email invitation. Confirm that **all invitations
were accepted** before continuing. If a volunteer does not accept, their test
fails for a reason outside the workflow.

**Evidence 1**: screenshot of the team page showing the N members.

### 1.2. Confirm every volunteer's notification preferences

Each volunteer opens `https://github.com/settings/notifications` and confirms:

- [ ] "Participating and @mentions" has **Email** checked
- [ ] The primary/preferred email is verified

Do not skip. If a volunteer has "Email" unchecked, their test fails for a
reason outside the workflow.

**Evidence 2**: each volunteer sends a screenshot of this page.

### 1.3. Push the lab to the org

```bash
cd lab-utils-notify
gh repo create welbsterhansi/lab-utils-notify --source=. --push --private
```

### 1.4. Point the caller at the test team

Open `.github/workflows/notify-release-images.yml` and set:

```yaml
with:
  teams: |
    @welbsterhansi/lab-notify-test
```

Commit and push.

---

## Phase 2 - Baseline test with `GITHUB_TOKEN`

Goal: confirm the Issue is created, and **measure whether the email arrives**
using the default token. Most likely no (expected).

### 2.1. Fire

```bash
gh workflow run notify-release-images.yml -f tag=v0.0.0-baseline
```

### 2.2. Wait 2 minutes and collect

- [ ] Green run in **Actions**. **Evidence 3**: link to the run.
- [ ] Issue created in **Issues** with label `release-notification`.
      **Evidence 4**: link to the Issue.
- [ ] Each volunteer checks their inbox and reports in the internal chat:
      "received email (YES/NO), time HH:MM"

Record this table:

| Volunteer | Received email? | Time |
|---|---|---|
| dev1 | ... | ... |
| dev2 | ... | ... |
| dev3 | ... | ... |

**Expected result**: most report NO. That confirms `GITHUB_TOKEN` is not
sufficient to notify team members.

If everyone reports YES: great, the org may be permissive; still proceed to
Phase 3 to have a robust guarantee.

---

## Phase 3 - Test with GitHub App

### 3.1. Create and install the App

Follow README section 2.2. Verify:

- [ ] App created with permissions: `Issues: R&W`, `Members: Read`, `Contents: Read`
- [ ] App installed on the `lab-utils-notify` repo
- [ ] Secrets `NOTIFY_APP_ID` and `NOTIFY_APP_PRIVATE_KEY` set on the repo

### 3.2. Enable the App in the template

In `.github/workflows/notify-release-images-template.yml`, **uncomment**:

1. The step `Generate GitHub App token`
2. The `github-token:` line inside the `Create announcement Issue` step

Commit and push.

### 3.3. Fire

```bash
gh workflow run notify-release-images.yml -f tag=v0.0.0-app
```

### 3.4. Wait 2 minutes and collect

Same table as Phase 2, now with the Phase 3 result:

| Volunteer | Received Phase 2 | Received Phase 3 | Diff |
|---|---|---|---|
| dev1 | NO | YES | App fixed it |
| dev2 | NO | YES | App fixed it |
| dev3 | NO | NO | Investigate (Phase 4) |

**Success criterion**: **100% of volunteers with correct preferences receive
email in Phase 3**.

If any developer did not receive despite correct preferences, see Phase 4
before promoting.

---

## Phase 4 - Diagnosing individual failures

If a volunteer did not receive in Phase 3:

1. **Confirm the App is installed with `Members: Read`**

   ```bash
   gh api /orgs/welbsterhansi/installations
   ```

   Find the App and check its permissions.

2. **Confirm the team is visible to the App**

   If the team has `privacy=secret`, the App may not see it. Switch to `closed`:

   ```bash
   gh api -X PATCH orgs/welbsterhansi/teams/lab-notify-test -f privacy=closed
   ```

3. **Confirm the mention was processed**

   Open the created Issue and locate the team name. If it renders as a
   clickable link, it was processed. If it renders as plain text, it was not.

4. **Confirm the volunteer's preferences**

   Repeat check 1.2 above.

5. **Confirm the corporate email filters**

   `notifications@github.com` may be caught by the bank's Exchange spam filter.
   Ask the volunteer to search for `from:notifications@github.com` in their
   email client.

---

## Phase 5 - Promotion to production

Only after Phase 3 passes 100%:

- [ ] Copy both workflow files from `.github/workflows/` to `container-utils`
- [ ] Copy the entire `scripts/notify/` directory to `container-utils`
- [ ] Rename `workflows: ["Release"]` in the caller to match the exact name of
      the client's release workflow
- [ ] Set `teams:` in the caller to the real consumer teams
- [ ] Set `NOTIFY_APP_ID` and `NOTIFY_APP_PRIVATE_KEY` secrets on `container-utils`
- [ ] Open PR, review, merge
- [ ] Run `workflow_dispatch` with `tag=v0.0.0-prod-test` on `container-utils`
- [ ] Confirm that **one developer from each real team** received the email
      (minimum sample; if any failure, go back to Phase 4)
- [ ] Publish a real release and observe

---

## Final report to the manager

At the end of Phase 5, deliver a short document with:

1. Date and time of each fire
2. Links to the runs (Phase 2, Phase 3, prod)
3. Links to the Issues created
4. Consolidated table of receipts (developer, phase, result)
5. Screenshot of at least one volunteer's inbox showing the email
6. Any deviation from this protocol with justification

Without this report, consider the validation not done.
