# Project: GitOps Workflow Rollout — it_macos

## Overview

This project migrates the `it_macos` repository to our new bash scripting standard and establishes a GitOps deployment pipeline that automatically syncs scripts to Jamf Pro on merge. The rollout follows a test-first approach before touching production, and concludes by introducing the workflow to the broader team with enforced PR review requirements.

**Repository:** `it_macos`
**Script count:** 61 scripts in repo (33 Extension Attributes, 28 regular scripts) + unknown number in Jamf Pro not yet in git
**Owner:** Matthew Parker

---

## Goals

- All scripts in `it_macos` meet the bash scripting standard
- Merging to `main` automatically deploys changed scripts to Jamf Pro
- Test instance validates changes before they reach production
- Team understands the standard and workflow before it is enforced
- No script reaches Jamf Pro without a passing CI check and peer review

## Milestones

Each phase ends at a milestone — a clearly defined point where something is true that wasn't before. Use these to track and communicate progress.

| # | Milestone | Definition of Done | Phase | Points |
|---|---|---|---|---|
| M1 | Inventory Complete | Every script in Jamf Pro is accounted for. All untracked scripts have a recorded decision: add to repo, leave unmanaged, or deprecate. No unknowns remain. | 0 | 17 |
| M2 | All Scripts on Standard | Every managed script has a compliant header, `SCRIPT_VERSION` constant, correct safe mode flags, and passes ShellCheck. Pre-commit hooks are active. | 1 | 33 |
| M3 | Pipeline Live on Test | A merge to `main` automatically deploys changed scripts to the test Jamf instance without any manual steps. | 2 | 15 |
| M4 | Test Validated | All managed scripts are confirmed present in test Jamf Pro. Create and update both work. A script has been executed via a Jamf policy on a test device and the log output is correct. | 3 | 11 |
| M5 | Team Onboarded | Standards are published. The team has seen a live demo. Branch protection is enabled — no script can reach Jamf Pro without a PR, CI check, and approval. | 4 | 9 |
| M6 | Pipeline Live on Production | All managed scripts are present in production Jamf Pro via the pipeline. Old manually-managed duplicates are cleaned up. Production is the source of truth. | 5 | 12 |
| — | **Total** | | | **97** |

---

## Success Criteria

- [ ] M1 — Full inventory complete, no untracked scripts
- [ ] M2 — All managed scripts meet the bash scripting standard
- [ ] M3 — Pipeline deploys to test automatically on merge
- [ ] M4 — Test instance validated end-to-end including script execution
- [ ] M5 — Team onboarded, branch protection enabled
- [ ] M6 — Production pipeline live, old scripts reconciled

---

## Architecture: Test vs Production

The Shikomi deploy workflow is single-environment by default. To support test and production without managing two repositories, we use **GitHub Actions Environments**.

Each environment (`test` and `production`) holds its own set of secrets and can require manual approval before the deployment job runs. The workflow file references the environment by name — secrets are injected automatically based on which environment is active.

```
Merge to main
      │
      ▼
┌─────────────┐     automatic     ┌─────────────────────┐
│  CI checks  │ ────────────────► │  Deploy → TEST      │
│  ShellCheck │                   │  jamf-test.company  │
│  Gitleaks   │                   └──────────┬──────────┘
└─────────────┘                              │
                                    manual approval
                                             │
                                             ▼
                                   ┌─────────────────────┐
                                   │  Deploy → PROD      │
                                   │  jamf.company       │
                                   └─────────────────────┘
```

**GitHub Environments setup:**
- `test` — auto-deploys on every merge to main, no approval required
- `production` — requires manual approval in the GitHub Actions UI before deploying

This means every merge goes to test automatically. Promoting to production is a deliberate, one-click action in GitHub with a full audit trail.

---

## Important: EAs vs Scripts

The Shikomi deploy workflow calls two Jamf Pro APIs depending on file type: the
**Scripts API** (`/api/v1/scripts`) for regular scripts, and the **Extension
Attribute API** (`/api/v1/computer-extension-attributes`) for files ending
`_ea.sh`. Both `jamf/Scripts/` and `jamf/EAs/` are covered by the same
`deploy-to-jamf.yml` workflow — see Phase 6 below for what shipped and what
still needs manual verification against a live Jamf Pro instance before
production use.

---

## Phase 0 — Inventory & Reconciliation

> Before migrating anything, establish a complete picture of what exists in Jamf Pro and how it maps to the repository. The outcome of this phase determines the true scope of Phase 1.

Scripts in Jamf Pro that aren't in the repo are invisible to the pipeline. If they get deployed alongside new GitOps-managed scripts without being reconciled, you'll have two classes of scripts in Jamf: versioned ones the pipeline owns, and untracked ones that can only be changed manually. This phase closes that gap before it becomes a permanent fixture.

---

### 0.1 Export Scripts and EAs from Jamf Pro — 2

**Description**
Export the complete list of Scripts and Extension Attributes from both Jamf Pro instances via API. Scripts and EAs are separate resources and must be exported independently.

**Requirements**

```bash
# Authenticate first (run once per instance session)
TOKEN=$(curl -s -X POST \
  "https://your-instance.jamfcloud.com/api/v1/auth/token" \
  -u "client_id:client_secret" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

# Export Scripts (paginate if you have more than 100)
curl -s \
  "https://your-instance.jamfcloud.com/api/v1/scripts?page=0&page-size=100" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '[.results[] | {id, name}]'

# Export Extension Attributes
curl -s \
  "https://your-instance.jamfcloud.com/api/v1/computer-extension-attributes?page=0&page-size=100" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '[.results[] | {id, name}]'
```

- [ ] Export Scripts from production Jamf Pro
- [ ] Export EAs from production Jamf Pro
- [ ] Export Scripts from test Jamf Pro (if it has content)
- [ ] Export EAs from test Jamf Pro (if it has content)
- [ ] Save outputs to `docs/audit/` and add that directory to `.gitignore`

**Definition of Done**
Four export files exist locally: `prod-scripts.json`, `prod-eas.json`, `test-scripts.json`, `test-eas.json`. No browsing the Jamf UI — the API export is the authoritative list.

---

### 0.2 Build the Comparison — 3

**Description**
Create a side-by-side inventory comparing what is in the repo against what is in Jamf Pro for both Scripts and EAs. Do not make decisions at this stage — just list everything.

**Requirements**

- [ ] List all scripts in `jamf/Scripts/` (28 known)
- [ ] List all EAs in `jamf/EAs/` (33 known)
- [ ] Cross-reference against `prod-scripts.json` and `prod-eas.json`
- [ ] Record every item in the decision table in 0.4

**Definition of Done**
Every script and EA found in either the repo or Jamf Pro appears in the comparison table with its source(s) noted.

---

### 0.3 Identify the Gaps — 2

**Description**
Categorize every script and EA from the comparison into one of four categories so decisions can be made in 0.4.

**Requirements**

Assign each item one of the following categories:

| Category | Description | Next Action |
|---|---|---|
| **In repo + in Jamf** | Exists in both, names match | Confirm content matches |
| **In repo only** | Not yet in Jamf | No action — pipeline creates it on first deploy |
| **In Jamf only** | Exists in Jamf but not tracked in git | Decision required in 0.4 |
| **Name mismatch** | Same script, different names in Jamf vs repo | Canonical name decision required in 0.5 |

> **Why name mismatches matter:** The deploy workflow looks up scripts by name. If a script is called `Install Cyberhaven` in Jamf but `installCyberhaven` in the repo, the pipeline will create a second entry rather than updating the existing one.
>
> **Resolving mismatches:** Add a `# JAMF_NAME: <Jamf display name>` line to the script header. The deploy workflow reads this field and uses it as the Jamf lookup name, falling back to the filename if absent. This lets you control the Jamf name without renaming scripts in Jamf or touching policy references.

- [ ] Assign a category to every item in the comparison table

**Definition of Done**
Every script and EA has a category. No items are uncategorized.

---

### 0.4 Decision Table — Jamf-Only Scripts — 5

**Description**
For every script or EA that exists in Jamf but has no counterpart in the repo, make and record a decision about how it will be handled going forward.

**Requirements**

| Jamf Script Name | Type | Decision | Notes |
|---|---|---|---|
| *(fill in from export)* | Script / EA | Add to repo / Leave unmanaged / Deprecate | |

Decision guidance:
- **Add to repo** — Script is actively used by a policy. Add it to `jamf/Scripts/` or `jamf/EAs/` and include it in Phase 1.
- **Leave unmanaged** — Script is in use but intentionally out of scope (e.g. vendor-provided, one-off). Document why.
- **Deprecate** — Script is no longer referenced by any policy. Remove from Jamf Pro.

- [ ] Review each Jamf-only script against policy usage
- [ ] Record a decision for every item
- [ ] Document unmanaged scripts in `docs/audit/unmanaged-scripts.md`

**Definition of Done**
Every Jamf-only script has a recorded decision. No item is left as "unknown."

---

### 0.5 Resolve Name Mismatches — 3

**Description**
For every script that exists in both the repo and Jamf Pro but with different names, choose a canonical name before the pipeline goes live to prevent duplicate entries being created on first deploy.

**Requirements**

- [ ] List all name mismatches identified in 0.3
- [ ] For each mismatch, add `# JAMF_NAME: <current Jamf name>` to the script header in the repo — the pipeline will find the existing Jamf entry and update it rather than creating a duplicate
- [ ] Scripts that use the `(Parameters Required)` naming convention should use `JAMF_NAME` to preserve that suffix (e.g. `# JAMF_NAME: myScript (Parameters Required)`)
- [ ] Do **not** rename scripts in Jamf Pro unless the existing Jamf name is wrong — renaming in Jamf risks breaking policy references

**Definition of Done**
Every script that exists in both locations either has a matching name or has a `JAMF_NAME` header set to the Jamf name. No mismatches remain that would cause the pipeline to create a duplicate.

---

### 0.6 Update Phase 1 Scope — 2

**Description**
Apply the findings from Phase 0 to the Phase 1 task lists so the migration reflects the true scope of work.

**Requirements**

- [ ] Add any Jamf-only scripts (decided "Add to repo") to the migration tables in 1.3 or 1.4
- [ ] Update the script counts in the Overview to reflect the final total
- [ ] Document any scripts intentionally left unmanaged in `docs/audit/unmanaged-scripts.md`

**Definition of Done**
The Phase 1 migration tables are complete and accurate. The script count in the Overview reflects reality.

---

> **M1 — Inventory Complete**
> Every script in Jamf Pro is accounted for. All untracked scripts have a recorded decision. No unknowns remain.

---

## Phase 1 — Migrate Scripts to Standard

> Bring all scripts into compliance with the bash scripting standard. This is done locally before any pipeline work begins. The script lists below reflect the repo as of the start of the project — update them with any additions from Phase 0.

---

### 1.1 Prepare the Repository — 2

**Description**
Set up the local environment and working branch before any scripts are touched.

**Requirements**

- [ ] Confirm `it_macos` is on the latest commit from remote
- [ ] Create a working branch: `feature/scripting-standard-migration`
- [ ] Install ShellCheck if not already present: `brew install shellcheck`
- [ ] Install pre-commit if not already present: `brew install pre-commit`
- [ ] Confirm bump-version is installed system-wide (via Shikomi's `install.sh`)

**Definition of Done**
Working branch is created, all required local tools are installed and available.

---

### 1.2 Configure Repository Tooling — 3

**Description**
Add the repo-level tooling that `it_macos` is missing: a `.gitignore`, pre-commit hooks, and hook activation. These are one-time tasks for the repository.

**Requirements**

- [ ] Add `.gitignore` covering secrets, binaries, and macOS system files (see scripting standards)
- [ ] Add `.pre-commit-config.yaml` with enhanced hook set: gitleaks, shellcheck, trailing-whitespace, end-of-file-fixer, check-yaml, check-added-large-files, check-merge-conflict, detect-private-key
- [ ] Run `pre-commit install` to activate hooks
- [ ] Run `pre-commit run --all-files` and fix any immediate failures before proceeding

> Shikomi can generate the `.pre-commit-config.yaml`: run `shikomi --hooks enhanced` in the repo root, then copy out the config file.

**Definition of Done**
Pre-commit hooks are installed and `pre-commit run --all-files` passes with no failures.

---

### 1.3 Migrate Regular Scripts (jamf/Scripts/) — 13

**Description**
Apply the bash scripting standard to every script in `jamf/Scripts/`. Each script needs a compliant header, versioning constants, safe mode, and standard logging. Update the count below if Phase 0 added scripts to scope.

**Requirements**

For each script:

- [ ] Add compliant file header (SCRIPT, VERSION, AUTHOR, EMAIL, DATE, Description, PARAMETERS, CHANGELOG)
- [ ] Add `readonly SCRIPT_VERSION="1.0.0"` and `readonly SCRIPT_NAME="script_name"` constants
- [ ] Add `set -euo pipefail` after the header block
- [ ] Add standard logging functions block
- [ ] Add `log "Starting $SCRIPT_NAME v$SCRIPT_VERSION..."` as first runtime line
- [ ] Verify all parameters use the `${4:-}` pattern with startup logging
- [ ] Verify no hardcoded secrets
- [ ] Run `shellcheck --severity=warning <script>.sh` and fix all warnings

Scripts to migrate:

| Script | Parameters | Notes |
|---|---|---|
| configureDefaultDock.sh | | |
| configureLocationServices.sh | | |
| configureScreensharing.sh | | |
| confirmJumpcloudPassword.sh | | |
| createNewUser.sh | | |
| creator_studio_cleanup.sh | | |
| deferredJamfMigration.sh | | |
| delete_apple_default_apps.sh | | |
| delete_iwork.sh | | |
| deletePPChangeUser.sh | | |
| enableScreenShare.sh | | |
| homeFolderRename.sh | | |
| installCyberhaven.sh | | |
| installJamfandReconFromJCDS.sh | | |
| InstallJumpCloudAgentandBind.sh | | |
| installJumpCloudAgentandBindWithNotifications.sh | | |
| jumpCloudInstallBind_dialogs.sh | | |
| logCollection.sh | | |
| macOSSonomaUpgradeAlert.sh | | |
| MigrateComputerAlert.sh | | |
| migrateToJamf.sh | | |
| newMigrationAlert.sh | | |
| newMigrationAlertOutOfDeferrals.sh | | |
| PPMacConfig.sh | | |
| reconAsUser.sh | | |
| removeTenableNessusPrefPane.sh | | |
| renamecomputer.sh | | |
| setChromeDefaultBrowser.sh | | |
| setDefaultBrowserSelfService.sh | | |
| slackEnrollmentWebhook.sh | | |
| upgradeBrewFormula.sh | | |
| userNameChange.sh | | |

**Definition of Done**
Every script in `jamf/Scripts/` has a compliant header, `SCRIPT_VERSION` constant, `set -euo pipefail`, standard logging, and passes `shellcheck --severity=warning` with no warnings.

---

### 1.4 Migrate Extension Attributes (jamf/EAs/) — 13

**Description**
Apply the bash scripting standard to every EA in `jamf/EAs/`. EAs have an additional constraint: the only stdout output must be `echo "<result>${RESULT}</result>"`. They also use `set -uo pipefail` instead of `set -euo pipefail` to prevent silent failures that would leave Jamf with no result.

**Requirements**

For each EA:

- [ ] Add compliant EA file header (SCRIPT, VERSION, DESCRIPTION, AUTHOR, EMAIL, History)
- [ ] Add `readonly SCRIPT_VERSION="1.0.0"` constant
- [ ] Add `set -uo pipefail` (not `set -euo pipefail` — see scripting standards)
- [ ] Ensure all non-result output goes to stderr via logging functions or `>&2`
- [ ] Ensure result is wrapped: `echo "<result>${RESULT}</result>"`
- [ ] Add fallback: `RESULT="${RESULT:-Not Available}"`
- [ ] Run `shellcheck --severity=warning <script>_ea.sh` and fix all warnings
- [ ] Test locally — output must be exactly `<result>VALUE</result>`

EAs to migrate:

| Script | Notes |
|---|---|
| appPatchingLastRun_ea.sh | |
| batteryCycleCount_ea.sh | |
| brewInstallStatus_ea.sh | |
| claude_extensions_ea.sh | |
| computerIsActive_ea.sh | |
| crowdStrikeStatus_ea.sh | |
| cveExploits_ea.sh | |
| cyberhavenStatus_ea.sh | |
| ddm_plan_ea.sh | |
| deploymentGroup_ea.sh | |
| downloadedmacOSVersion_ea.sh | |
| finalComputerSetupDate_ea.sh | |
| homeBrewVersion_ea.sh | |
| iCloudAccount_ea.sh | |
| installedChromeExtensions_ea.sh | |
| javaVendor_ea.sh | |
| JCAccountStatus_ea.sh | |
| lastFullInventory_ea.sh | |
| macOSVersionCheck_ea.sh | |
| migrationDeferrals_ea.sh | |
| PatchingGroup_ea.sh | |
| prizepicksBrandingImages_ea.sh | |
| secureTokenUsers_ea.sh | |
| SequoiaEarlyAdopterStatus_ea.sh | |
| setupManagerDate_ea.sh | |
| setupManagerStatus_ea.sh | |
| superNextAutoLaunchDate_ea.sh | |
| superStatus_ea.sh | |
| superVersion_ea.sh | |
| tenableNessusAgentStatus_ea.sh | |
| tenableNessusAgentVersion_ea.sh | |
| tenableNessusStatus_ea.sh | |

**Definition of Done**
Every EA in `jamf/EAs/` has a compliant header, `SCRIPT_VERSION` constant, correct safe mode flags, passes ShellCheck, and outputs exactly `<result>VALUE</result>` when run locally.

---

### 1.5 Commit the Migration — 2

**Description**
Run a final pre-commit check across all files, commit the migration, and open the PR that will serve as the baseline for the entire pipeline.

**Requirements**

- [ ] Run `pre-commit run --all-files` — all checks must pass
- [ ] Commit: `git commit -m "chore: migrate all scripts to scripting standard v1.0.0"`
- [ ] Open a PR from `feature/scripting-standard-migration` to `main`
- [ ] Self-review the diff — this is the baseline for the entire pipeline

**Definition of Done**
PR is open, all CI checks pass, and the diff has been reviewed.

---

> **M2 — All Scripts on Standard**
> Every managed script has a compliant header, `SCRIPT_VERSION` constant, correct safe mode flags, and passes ShellCheck. Pre-commit hooks are active on the repo.

---

## Phase 2 — Configure GitOps Pipeline (Test Instance)

> Set up the GitHub Actions deploy workflow pointed at the test Jamf instance. No production secrets are used in this phase.

---

### 2.1 Jamf Pro Test Instance — API Credentials — 3

**Description**
Create the API Role and Client in the test Jamf Pro instance that the GitHub Actions deploy workflow will use to authenticate and manage scripts.

**Requirements**

- [ ] Go to Settings > System > API Roles and Clients in the test instance
- [ ] Create an API Role named `GitHub Deploy — Scripts` with permissions: Read Scripts, Create Scripts, Update Scripts
- [ ] Create an API Client named `github-deploy`, assign the role, set an appropriate token expiration
- [ ] Copy the Client ID and generate and copy the Client Secret

**Definition of Done**
An API Client exists in the test Jamf Pro instance with the correct role. Client ID and Client Secret are saved securely and ready to add to GitHub.

---

### 2.2 GitHub Repository — Environments & Secrets — 2

**Description**
Configure two GitHub Actions Environments in the `it_macos` repository — one for test (auto-deploys) and one for production (requires manual approval). Add the test Jamf credentials to the test environment.

**Requirements**

- [ ] Go to Settings > Environments in the `it_macos` GitHub repository
- [ ] Create environment `test` with no approval requirement and add secrets: `JAMF_URL`, `JAMF_CLIENT_ID`, `JAMF_CLIENT_SECRET` pointing to the test instance
- [ ] Create environment `production` with Required Reviewers enabled — add yourself as reviewer. Leave secrets empty for now.

**Definition of Done**
Both environments exist in GitHub. The `test` environment has valid Jamf credentials. The `production` environment has approval protection configured but no secrets yet.

---

### 2.3 Add the Deploy Workflow — 8

**Description**
Add the GitHub Actions workflow files to the repository. The validate workflow runs on every PR; the deploy workflow runs on merge to main and deploys changed scripts to test automatically, then waits for manual approval before deploying to production.

**Requirements**

- [ ] Create `.github/workflows/validate.yml` — runs ShellCheck and version checks on every PR
- [ ] Create `.github/workflows/deploy.yml` — deploys changed scripts on merge to main, scoped to `jamf/Scripts/` only

The deploy workflow structure:

```yaml
# deploy.yml (outline — adapt from Shikomi's generated template)

on:
  push:
    branches: [main]
    paths: ['jamf/Scripts/**/*.sh']

jobs:
  deploy-test:
    environment: test
    runs-on: ubuntu-latest
    steps:
      - Detect changed versioned scripts (git diff + grep SCRIPT_VERSION)
      - Authenticate to Jamf Pro (OAuth with JAMF_CLIENT_ID + JAMF_CLIENT_SECRET)
      - For each changed script: lookup by name, create or update via API

  deploy-production:
    needs: deploy-test
    environment: production
    runs-on: ubuntu-latest
    steps:
      - Same deploy logic, different environment secrets
```

- [ ] Commit workflow files: `git commit -m "chore: add GitOps deploy workflow"`
- [ ] Push to `main` directly — branch protection is not yet enabled

**Definition of Done**
Both workflow files are committed to `main`. The validate workflow appears in GitHub Actions and is ready to run on PRs.

---

### 2.4 Validate CI is Running — 2

**Description**
Confirm that the validate and deploy workflows trigger correctly before merging the Phase 1 PR.

**Requirements**

- [ ] Confirm the `validate` workflow runs on the open Phase 1 PR
- [ ] Confirm ShellCheck passes for all scripts
- [ ] Merge the Phase 1 PR
- [ ] Confirm the `deploy` workflow triggers on merge and completes successfully

**Definition of Done**
The Phase 1 PR has been merged and the deploy workflow ran without errors.

---

> **M3 — Pipeline Live on Test**
> A merge to `main` automatically deploys changed scripts to the test Jamf instance without any manual steps.

---

## Phase 3 — Validate on Test Instance

> Verify the pipeline is working correctly end-to-end before touching production.

---

### 3.1 Verify Initial Deployment — 3

**Description**
After the Phase 1 merge triggers the first deploy, verify that all scripts from `jamf/Scripts/` are present in the test Jamf Pro instance with the correct names and content.

**Requirements**

- [ ] Open GitHub Actions and confirm the deploy job completed successfully
- [ ] Log in to test Jamf Pro and go to the Scripts library
- [ ] Verify all scripts from `jamf/Scripts/` appear — count should match the final total from Phase 0
- [ ] Spot-check 3 to 5 scripts: confirm the script body in Jamf matches the repo content
- [ ] Confirm version information appears in each script's Info field in Jamf

**Definition of Done**
All managed scripts are present in test Jamf Pro with correct names and content matching the repository.

---

### 3.2 Validate Create vs Update Behavior — 2

**Description**
Verify that the pipeline correctly creates new scripts and updates existing ones by making a real change and confirming the behavior in GitHub Actions.

**Requirements**

- [ ] Make a small change to one script (e.g. update a log message)
- [ ] Run `bump-version jamf/Scripts/<script>.sh patch "Test pipeline update" --commit`
- [ ] Push to main
- [ ] Confirm GitHub Actions shows UPDATE (not CREATE) for that script
- [ ] Confirm the change appears in the test Jamf Pro instance

> `bump-version` in `it_macos` requires the full relative path from the repo root. Verify this works correctly on first use — if bump-version does not find the file, confirm you are running the command from the repo root.

**Definition of Done**
A script change has been pushed, the pipeline updated the existing Jamf script (not created a duplicate), and the change is visible in Jamf Pro.

---

### 3.3 Validate Failure Cases — 2

**Description**
Confirm that CI correctly blocks bad code before it can be merged — the pipeline should only deploy scripts that pass validation.

**Requirements**

- [ ] Introduce a ShellCheck warning intentionally on a feature branch
- [ ] Confirm the `validate` workflow fails and blocks the PR
- [ ] Fix the warning and confirm CI passes

**Definition of Done**
A PR with a ShellCheck failure was blocked from merging. A corrected PR passed and was mergeable.

---

### 3.4 Test Script Execution in Jamf — 3

**Description**
Confirm that a pipeline-deployed script executes correctly when triggered via a Jamf policy, and that logging output is correct on the device.

**Requirements**

- [ ] Assign one low-risk script to a test policy scoped to a single test Mac
- [ ] Run the policy and confirm the script executes without errors
- [ ] Check `/var/log/<script_name>.log` on the test Mac and confirm log output is present and correctly formatted

**Definition of Done**
A script deployed via the pipeline has been executed through a Jamf policy and produced correct log output on a test device.

---

### 3.5 Sign Off on Test — 1

**Description**
Final checklist confirming the test phase is complete and production work can begin.

**Requirements**

- [ ] All managed scripts from `jamf/Scripts/` are present in test Jamf Pro
- [ ] Create and update both work correctly
- [ ] CI blocks non-compliant code before it can be merged
- [ ] Script execution confirmed on a test device

**Definition of Done**
All four requirements above are checked off. Production rollout is cleared to proceed.

---

> **M4 — Test Validated**
> All managed scripts are confirmed present in test Jamf Pro. Create and update both work. A script has been executed via a Jamf policy on a test device and log output is correct.

---

## Phase 4 — Team Introduction

> Before production is enabled, bring the team up to speed so the workflow is not a surprise.

---

### 4.1 Prepare Documentation — 5

**Description**
Publish the standards and workflow documentation and write a concise "how to submit a script change" guide for the team.

**Requirements**

- [ ] Publish the Bash Scripting Standards doc to Notion
- [ ] Publish this GitOps Rollout project doc to Notion
- [ ] Write a How to Submit a Script Change guide covering:
  - Clone the repo and create a feature branch
  - Edit the script and run ShellCheck locally
  - Use `bump-version` to version the change
  - Open a PR — CI runs automatically
  - PR requires one approval before merge
  - Merge triggers deployment to test, then production after approval

**Definition of Done**
All three documents are published to Notion and accessible to the team.

---

### 4.2 Team Demo — 3

**Description**
Run a live walkthrough of the full workflow so the team understands what happens when they make a script change.

**Requirements**

- [ ] Walk through a live end-to-end example: edit a script, open a PR, CI runs, merge, Jamf updates
- [ ] Show the GitHub Actions deployment summary
- [ ] Show the script appearing or updating in Jamf Pro
- [ ] Show what a failing CI check looks like and how to fix it

**Definition of Done**
The team has seen a complete end-to-end demo including a passing deploy and a failing CI check.

---

### 4.3 Enable Branch Protection — 1

**Description**
Lock down the `main` branch so that no script can reach Jamf Pro without a PR, a passing CI check, and a peer review. This is the final gate before production work begins.

**Requirements**

- [ ] Go to Settings > Branches > Branch protection rules in the `it_macos` GitHub repository
- [ ] Add a rule for `main` with: Require a pull request before merging, Require at least 1 approval, Require status checks to pass (select the `validate` workflow), Block direct pushes to main

**Definition of Done**
Branch protection is active on `main`. A direct push to main is rejected. A PR without CI passing cannot be merged.

---

> **M5 — Team Onboarded**
> Standards are published. The team has seen a live demo. Branch protection is enabled — no script can reach Jamf Pro without a PR, CI check, and approval.

---

## Phase 5 — Production Rollout

> Switch the pipeline to production after test has been validated and the team is briefed.

---

### 5.1 Jamf Pro Production Instance — API Credentials — 2

**Description**
Create the API Role and Client in the production Jamf Pro instance using the same configuration as test.

**Requirements**

- [ ] Go to Settings > System > API Roles and Clients in the production instance
- [ ] Create an API Role named `GitHub Deploy — Scripts` with permissions: Read Scripts, Create Scripts, Update Scripts
- [ ] Create an API Client named `github-deploy` and copy the Client ID and Client Secret

**Definition of Done**
An API Client exists in production Jamf Pro with the correct role. Credentials are saved securely and ready to add to GitHub.

---

### 5.2 Add Production Secrets to GitHub — 1

**Description**
Add the production Jamf Pro credentials to the `production` GitHub Environment so the deploy workflow can authenticate.

**Requirements**

- [ ] Go to the `production` environment in GitHub repository Settings
- [ ] Add secrets: `JAMF_URL`, `JAMF_CLIENT_ID`, `JAMF_CLIENT_SECRET` pointing to the production instance

**Definition of Done**
The `production` GitHub Environment has valid Jamf Pro credentials configured.

---

### 5.3 Initial Production Deployment — 3

**Description**
Trigger the first production deployment. Since no repo-managed scripts exist in production yet with matching names, this will be an all-create operation.

**Requirements**

- [ ] Approve the pending production environment deployment in GitHub Actions (or trigger manually via Actions > deploy > Run workflow)
- [ ] Monitor the deploy job output
- [ ] Log in to production Jamf Pro and confirm all scripts from `jamf/Scripts/` are present — count should match the final total from Phase 0
- [ ] Spot-check names and content match the repository

**Definition of Done**
All managed scripts from `jamf/Scripts/` are present in production Jamf Pro with correct names and content.

---

### 5.4 Clean Up Superseded Jamf Scripts — 5

**Description**
The initial production deploy creates new GitOps-managed entries for all repo scripts. Any existing Jamf scripts with different names are now duplicates. This issue covers identifying and safely removing the old manually-managed versions and updating any policies that referenced them.

**Requirements**

- [ ] Review the name mismatch list from Phase 0.5
- [ ] For each superseded script: confirm the new GitOps version is working correctly, then delete the old manually-managed entry from Jamf Pro
- [ ] Update any Jamf policies that referenced the old script name to point to the new entry
- [ ] Confirm no policies are left pointing at deleted or deprecated scripts

> Once a script is deployed via the pipeline, the repository is the source of truth. Any edits made directly in the Jamf Pro UI will be overwritten on the next deploy.

**Definition of Done**
No duplicate scripts remain in Jamf Pro. All policies reference the GitOps-managed versions. No policy is pointing at a deleted script.

---

### 5.5 Sign Off on Production — 1

**Description**
Final checklist confirming production is fully live and the team has been notified.

**Requirements**

- [ ] All managed scripts from `jamf/Scripts/` are present in production Jamf Pro
- [ ] A test change has deployed successfully through the full pipeline (test > approval > production)
- [ ] Team has been notified that the production pipeline is live

**Definition of Done**
All three requirements above are checked off. The GitOps workflow is the sole path to deploying scripts to production.

---

> **M6 — Pipeline Live on Production**
> All managed scripts are present in production Jamf Pro via the pipeline. Old manually-managed duplicates are cleaned up. The repository is the authoritative source of truth for all managed scripts.

---

## Phase 6 — EA Pipeline (Complete)

> Extension Attributes are now covered by the same deploy workflow as regular scripts.

The Shikomi deploy workflow branches per-file: `/api/v1/scripts` for regular
scripts, `/api/v1/computer-extension-attributes` for files ending `_ea.sh`
(same convention `bump-version.sh` already uses to distinguish EAs). This
endpoint is confirmed correct against the official Jamf Pro API docs — no
change needed to what this doc already stated.

**Work required:**
- [x] Build a deploy path that calls the EA API endpoint — implemented as an
  inline branch inside the existing `generate_deploy_workflow()` /
  `generate_monorepo_deploy_workflow()` job (Shikomi `lib/workflows.sh`), not a
  separate job. A push can touch both a script and an EA in the same commit;
  branching inside the existing per-file loop handles that, a separate job
  would not.
- [ ] Add Read, Create, and Update Computer Extension Attributes permissions to
  the API Role — this is a manual, per-Jamf-instance operational step; the
  code change doesn't grant Jamf permissions for you. See
  `docs/reference-jamf-pro-api-setup.md`.
- [ ] ~~Scope the path trigger to `jamf/EAs/**/*.sh`~~ — intentionally **not**
  done. The Script/EA decision happens per-file inside the existing job
  (matched on the `_ea.sh` suffix), not at the trigger level, so no separate
  path-scoped trigger is needed or wanted — it would only fragment one push's
  deploy into two workflow runs.
- [ ] Test against a test instance before enabling for production — still
  open. The EA payload shape (field names, required fields, enum values) and
  the create/update/lookup behavior were verified against Jamf's published API
  documentation, not a live instance. Before production use, confirm live:
  the exact payload is accepted by `POST`/`PUT
  /api/v1/computer-extension-attributes`; the granted API Role authorizes both
  endpoint families under one client/token; the `name==` RSQL filter behaves
  the same on this endpoint as on `/api/v1/scripts`; a full-object PUT with a
  missing required field fails loudly (400) rather than partially applying;
  and an end-to-end create + update of a fresh test EA keeps the same Jamf
  `id` across updates rather than creating a duplicate.

EAs now deploy automatically once `deploy-to-jamf.yml` is present in the repo
and the API Role has the 3 EA permissions granted alongside the 3 Scripts
permissions.

---

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Jamf-only scripts missed during inventory | Phase 0 exports the full script list via API — do not rely on manually browsing the UI. |
| Name mismatches cause duplicate scripts on first deploy | Phase 0.5 identifies all mismatches. Add `JAMF_NAME` headers to repo scripts to match existing Jamf names — no Jamf renaming required. |
| Policy references break after renaming | Phase 5.4 requires updating all affected policies before deleting old scripts. |
| Script edited in Jamf UI after pipeline is live | Pipeline overwrites on next deploy. Team norm: repo is source of truth, no UI edits. |
| JAMF_NAME removed without renaming in Jamf first | Pipeline won't find the existing entry and creates a duplicate. Before removing `# JAMF_NAME:`, manually rename the script in Jamf to match the filename and update policy references. See scripting standards. |
| API credentials expire mid-workflow | Set calendar reminders before token expiration. GitHub Actions will surface auth failures clearly. |
| EA duplicate created on first deploy (pre-existing EA's Jamf name doesn't match filename) | Add `# JAMF_NAME:` header before first deploy for any pre-existing EA — same mitigation as Scripts, see Phase 0.5. Also add `# JAMF_DATA_TYPE:`/`# JAMF_DISPLAY_CATEGORY:` matching the EA's current Jamf config before first deploy, since the API does a full-object replace on update and omitted fields fall back to `STRING`/`EXTENSION_ATTRIBUTES`, which could overwrite a differently-configured EA. |
| Team bypasses PR workflow | Branch protection enforces it — direct pushes to main are blocked. |

---

## Reference

| Resource | Location |
|---|---|
| Bash Scripting Standards | Notion — IT / Engineering Standards |
| Shikomi documentation | `shikomi --help` |
| bump-version documentation | `bump-version --help` |
| it_macos repository | GitHub — it_macos |
| GitHub Actions workflows | it_macos > .github/workflows/ |
| Jamf Pro test instance API clients | Settings > System > API Roles and Clients |
| Jamf Pro production instance API clients | Settings > System > API Roles and Clients |

---

*Owner: Matthew Parker — Last updated: 2026-04-28*
