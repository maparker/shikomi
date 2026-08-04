# Monorepo GitOps Workflow Guide

How to create, update, and migrate scripts in a monorepo using Shikomi's GitOps pipeline. This guide covers the full lifecycle from feature branch to Jamf Pro deployment.

---

## The Core Principle

**The repo is the source of truth. Jamf Pro is the deployment target.**

No one edits scripts in the Jamf Pro UI. Every change flows through:

```
branch → PR → review → merge → auto-deploy
```

---

## Prerequisites

Before starting, your monorepo needs:

- [x] GitHub Actions workflows generated (run `shikomi <script_name> --auto --deploy-workflow y` from inside the repo, or `add_security_tools.sh`)
- [x] GitHub secrets configured: `JAMF_URL`, `JAMF_CLIENT_ID`, `JAMF_CLIENT_SECRET`
- [x] Branch protection on `main` (recommended — see "Branch Protection" section below)

---

## New Script

### 1. Create a feature branch and scaffold with Shikomi

```bash
cd /path/to/your-scripts-repo
shikomi my_new_script --auto --claude y --branch y
```

Shikomi detects the existing repo (monorepo mode), creates a feature branch, and generates a versioned script with `readonly SCRIPT_VERSION="1.0.0"`.

### 2. Write the actual logic

Edit the generated script and replace the `# TODO` section with your implementation.

### 3. Commit

Pre-commit hooks run automatically when you commit:
- **Gitleaks** scans for accidentally committed secrets
- **ShellCheck** validates script quality

```bash
git add my_new_script.sh
git commit -m "feat: add my_new_script"
```

If a hook fails, the commit is blocked. Fix the issue and try again.

### 4. Push and open a PR

```bash
git push -u origin feature/my_new_script
gh pr create --title "Add my_new_script" --body "Description of what this script does"
```

### 5. CI validates the PR

`validate-scripts.yml` runs automatically:
- ShellCheck on all changed `.sh` files
- Gitleaks secret scan

The PR shows pass/fail badges. Reviewers see what passed before approving.

### 6. Review and merge

A teammate reviews and approves the PR. Once merged to `main`:

### 7. Auto-deploy to Jamf Pro

`deploy-to-jamf.yml` fires automatically:
1. Detects `my_new_script.sh` changed in the merge commit
2. Finds `readonly SCRIPT_VERSION="1.0.0"`
3. Looks up "my_new_script" in Jamf Pro (not found)
4. **Creates** it via the Jamf Pro API
5. Posts a deployment summary to the GitHub Actions run

---

## Updated Script

### 1. Create a feature branch

```bash
git checkout -b fix/my_new_script-permissions
```

### 2. Edit the script

Make your changes.

### 3. Bump the version

```bash
bump-version my_new_script.sh patch "Fixed permission check" --commit
```

This updates the version in the script header, README, and CHANGELOG, then commits the changes.

### 4. Push and open a PR

```bash
git push -u origin fix/my_new_script-permissions
gh pr create --title "Fix permission check in my_new_script" --body "Description"
```

### 5. CI validates, teammate reviews, merge

Same flow as above.

### 6. Auto-deploy to Jamf Pro

`deploy-to-jamf.yml` fires automatically:
1. Detects `my_new_script.sh` changed
2. Finds `readonly SCRIPT_VERSION="1.0.1"` (bumped)
3. Looks up "my_new_script" in Jamf Pro (found)
4. **Updates** it via the Jamf Pro API
5. Posts deployment summary

---

## Migrating a Legacy Script

Legacy scripts (without `readonly SCRIPT_VERSION=`) don't auto-deploy. To bring them into the pipeline:

### 1. Create a branch

```bash
git checkout -b migrate/configureDefaultDock
```

### 2. Add the version header

Add this line to the existing script, near the top after the header comment block:

```bash
readonly SCRIPT_VERSION="1.0.0"
```

That's it. No other changes required for the workflow to pick it up.

### 3. Commit, push, PR

```bash
git add jamf/Scripts/configureDefaultDock.sh
git commit -m "feat: add version tracking to configureDefaultDock"
git push -u origin migrate/configureDefaultDock
gh pr create --title "Version configureDefaultDock for GitOps" --body "Adds SCRIPT_VERSION for auto-deploy"
```

### 4. Merge and deploy

On merge, the deploy workflow:
1. Detects `configureDefaultDock.sh` changed
2. Finds the new `readonly SCRIPT_VERSION="1.0.0"`
3. Looks up "configureDefaultDock" in Jamf Pro (found — it was uploaded manually before)
4. **Updates** it via the API, bringing it under GitOps control

From this point forward, all changes to this script go through the PR workflow.

### Migration strategy

You don't need to migrate all scripts at once. The recommended approach:

1. Start with one script — add `SCRIPT_VERSION`, merge, verify it deploys correctly
2. Migrate scripts as you touch them — when you need to update a legacy script, add versioning at the same time
3. Bulk migrate when ready — add `SCRIPT_VERSION` to remaining scripts in batches

---

## Multiple Scripts in One PR

When a PR changes multiple versioned scripts, the deploy workflow handles all of them:

```bash
# Edit two scripts on the same branch
git checkout -b update/q1-changes
# ... edit configureDefaultDock.sh and delete_apple_default_apps.sh ...
bump-version configureDefaultDock.sh patch "Updated dock items" --commit
bump-version delete_apple_default_apps.sh minor "Added iWork removal" --commit
git push -u origin update/q1-changes
gh pr create --title "Q1 script updates" --body "Updated dock config and app deletion"
```

On merge, the deploy workflow:
1. Detects both scripts changed
2. Deploys each one in sequence
3. Posts a summary table:

```
## Deployment Summary

Deployed: 2 | Failed: 0

| Script | Version | Type | Action | Path | Status |
|--------|---------|------|--------|------|--------|
| configureDefaultDock | 1.0.1 | Script | update | jamf/Scripts/configureDefaultDock.sh | success |
| santa_sysext_removable_ea | 1.0.1 | EA | update | jamf/EAs/santa_sysext_removable_ea.sh | success |
```

---

## Extension Attributes

EAs (any file ending `_ea.sh`) deploy the same way regular scripts do — same
merge trigger, same per-file loop, same create/update detection — but target
Jamf Pro's Extension Attribute API (`/api/v1/computer-extension-attributes`)
instead of the Scripts API. Two optional headers control the EA's Jamf
metadata:

```bash
# JAMF_DATA_TYPE: STRING
# JAMF_DISPLAY_CATEGORY: EXTENSION_ATTRIBUTES
```

If omitted, they default to `STRING` / `EXTENSION_ATTRIBUTES`. As with regular
scripts, add a `# JAMF_NAME:` header if the Jamf display name needs to differ
from the filename. The API Role backing your `JAMF_CLIENT_ID`/`JAMF_CLIENT_SECRET`
needs the Read/Create/Update Computer Extension Attributes permissions in
addition to the Scripts permissions (see
`docs/reference-jamf-pro-api-setup.md`).

For any EA that predates this feature, check its actual Jamf display name and
current Data Type/Inventory Display before the first automated deploy — see
`docs/project-gitops-rollout.md` Phase 6 for the migration steps. Without a
matching `# JAMF_NAME:` header, a pre-existing EA whose Jamf name doesn't match
its filename will get a duplicate created instead of being updated.

---

## What Doesn't Deploy

| Scenario | Why |
|----------|-----|
| Script or EA without `readonly SCRIPT_VERSION=` | Not versioned — skipped by design |
| `bump-version.sh` changed (legacy) | Excluded by name filter |
| Script or EA deleted from repo | File no longer exists — skipped |
| Changes only to README, CHANGELOG, or docs | Path filter only triggers on `*.sh` |
| Direct push to main (with branch protection) | Blocked — must go through PR |

---

## Branch Protection

Branch protection is what prevents anyone from bypassing the PR workflow and pushing directly to `main`. Configure it in your GitHub repo: **Settings > Branches > Add branch ruleset** for `main`.

**Recommended settings:**
- Require pull request before merging
- Require at least 1 approval
- Require status checks to pass (select `Validate Scripts`)

**For teams on GitHub Team/Enterprise:** Create an organization-level ruleset that applies to all repos so you don't have to configure it per-repo.

**For solo admins on free GitHub accounts:** You can't approve your own PRs. Skip the approval requirement but still require status checks to pass. The CI checks (ShellCheck, Gitleaks) still catch problems automatically. Add the approval requirement later when you have a teammate to review your work.

---

## Quick Reference

| Task | Command |
|------|---------|
| New script in monorepo | `shikomi my_script --auto --claude y --branch y` |
| Bump version after changes | `bump-version my_script.sh patch "Description" --commit` |
| Push and open PR | `git push -u origin my-branch && gh pr create` |
| Add deploy workflow to existing repo | Run `add_security_tools.sh` from repo root |
| Migrate legacy script | Add `readonly SCRIPT_VERSION="1.0.0"` to the header |
| Check workflow status | `gh run list` or check the Actions tab on GitHub |
