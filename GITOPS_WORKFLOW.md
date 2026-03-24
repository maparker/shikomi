# GitOps Workflow Guide

A step-by-step guide to managing Jamf Pro scripts using Shikomi and a GitOps workflow. This document walks through the full lifecycle: from scaffolding a new project to deploying a validated script to Jamf Pro.

---

## Prerequisites

Before you begin, make sure you have the following installed:

- **Git** (required)
- **Shikomi** (installed via `install.sh`)
- **pre-commit** (`brew install pre-commit`)
- **GitHub CLI** (`brew install gh`) for repository creation and pull requests
- **1Password CLI** (`brew install 1password-cli`) if using 1Password for secrets

---

## Step 1: Scaffold a New Project

### Option A: Interactive Wizard

```bash
shikomi my_awesome_script
```

The interactive wizard walks you through:

1. **Template selection** (regular script or Extension Attribute)
2. **Jamf Pro parameters** ($4 through $11)
3. **Static configuration variables** (serial number, logged-in user, etc.)
4. **Secrets management** (1Password, file-based, or manual)
5. **Pre-commit hook level** (basic for secrets only, or enhanced for 9 checks)
6. **GitHub Actions workflows** (PR validation and optional Jamf Pro deployment)
7. **Claude Code configuration** (CLAUDE.md + SESSION_DIARY.md)

### Option B: Non-interactive (CLI Flags)

```bash
# Fully automated with defaults
shikomi my_awesome_script --auto

# Automated with all the bells and whistles
shikomi my_awesome_script --auto --workflow y --claude y --hooks enhanced

# With parameters from a JSON file
shikomi my_awesome_script --auto --params-file params.json --claude y
```

Run `shikomi --help` for all available flags.

### Generated Project Structure

```
my_awesome_script/
├── my_awesome_script.sh    # Your script (v1.0.0)
├── bump-version.sh         # Version management utility
├── README.md               # Auto-generated documentation
├── CHANGELOG.md            # Version history
├── .gitignore              # Security-focused ignore rules
├── .pre-commit-config.yaml # Secret scanning and linting hooks
├── CLAUDE.md               # Claude Code project config (if --claude y)
├── SESSION_DIARY.md        # Session tracking (if --claude y)
└── .github/
    └── workflows/
        ├── validate-version.yml   # PR validation (ShellCheck + version checks)
        └── deploy-to-jamf.yml     # Jamf Pro deployment (if selected)
```

---

## Step 2: Implement Your Logic

Open the generated script and replace the `TODO` section with your logic:

```bash
cd my_awesome_script
open my_awesome_script.sh
```

The script comes pre-wired with:
- Versioned header and metadata
- Parameter handling for Jamf Pro
- Secrets management (if configured)
- Logging functions (`log`, `log_warn`, `log_error`, `log_success`)

---

## Step 3: Test Locally

Run your script to verify it works:

```bashv
# Test with default parameter values
sudo ./my_awesome_script.sh

# Test with specific parameters (simulating Jamf Pro delivery)
sudo ./my_awesome_script.sh "" "" "" "param4_value" "param5_value"
```

Review the log output to confirm expected behavior:

```bash
cat /var/log/my_awesome_script.log
```

---

## Step 4: Commit Your Changes

### Tier 1 Protection: Pre-Commit Hooks

When you commit, pre-commit hooks run automatically on your machine before the commit is created:

- **Gitleaks** scans for accidentally committed secrets (API keys, tokens, passwords)
- **ShellCheck** validates your script for common bugs and style issues (enhanced mode)
- Additional quality checks like trailing whitespace, YAML validation, and large file detection (enhanced mode)

```bash
git add my_awesome_script.sh
git commit -m "feat: implement app installation logic"
```

If a hook fails, the commit is blocked with an actionable error message. Fix the issue and try again. No bad code leaves your machine.

### What a Blocked Commit Looks Like

```
gitleaks...............................................................Failed
- hook id: gitleaks
- exit code: 1

Finding:    API_KEY="sk-abc123..."
Secret:     sk-abc123...
File:       my_awesome_script.sh
Line:       42
```

Fix the issue (move the secret to 1Password or `~/.jamf_secrets`), then commit again.

---

## Step 5: Push and Open a Pull Request

Push your branch and create a pull request:

```bash
git push -u origin my-feature-branch

# Create a pull request using GitHub CLI
gh pr create --title "Add my_awesome_script" --body "Implements app installation logic"
```

### Tier 2 Protection: GitHub Actions Validation

When the pull request is opened, the `validate-version.yml` workflow runs automatically:

- **ShellCheck** lints the script in CI (catches anything missed locally)
- **Version consistency** verifies the version in the script header, `SCRIPT_VERSION` constant, and README all match
- **Gitleaks** scans for secrets at the PR level

The pull request shows pass/fail status for each check. Reviewers can see exactly what passed and what failed before approving.

---

## Step 6: Review and Merge

A teammate (or you, depending on your team's process) reviews the pull request:

- Code changes are visible in the diff
- CI checks must pass before merging
- Branch protection rules enforce required approvals (if configured)

Once approved, merge the pull request into `main`.

---

## Step 7: Deploy to Jamf Pro

If you selected the Jamf Pro deployment workflow during setup, the `deploy-to-jamf.yml` workflow triggers automatically when the pull request merges to `main`.

### What the Workflow Does

1. **Finds your versioned script** in the repository
2. **Authenticates** to Jamf Pro using OAuth (client credentials)
3. **Looks up** the script by name in Jamf Pro
4. **Creates or updates** the script via the Jamf Pro API
5. **Posts a deployment summary** to the GitHub Actions run

### Required GitHub Secrets

Before the first deployment, add these secrets to your repository (Settings > Secrets and variables > Actions):

| Secret | Description |
|--------|-------------|
| `JAMF_URL` | Your Jamf Pro URL (e.g. `https://yourinstance.jamfcloud.com`) |
| `JAMF_CLIENT_ID` | API client ID from Jamf Pro |
| `JAMF_CLIENT_SECRET` | API client secret from Jamf Pro |

### Setting Up API Credentials in Jamf Pro

1. In Jamf Pro, go to **Settings > System > API Roles and Clients**
2. Create a new **API Role** with these permissions:
   - Read Scripts
   - Create Scripts
   - Update Scripts
3. Create a new **API Client** and assign the role you created
4. Copy the **Client ID** and **Client Secret** to your GitHub repository secrets

### Adding Deployment to an Existing Repo

If you have an existing repository that wasn't scaffolded with the deploy workflow, run `add_security_tools.sh` from your repo root. It will prompt you to add the Jamf Pro deploy workflow alongside the security checks.

### Script Naming in Jamf Pro

The deploy workflow creates scripts in Jamf Pro **without** the `.sh` extension. For example, `install_app.sh` in your repo becomes `install_app` in Jamf Pro.

When updating, the workflow checks for both names (with and without `.sh`) so it will find existing scripts regardless of how they were originally named. However, if you are adding deployment to a repo where the script already exists in Jamf Pro with `.sh` in the name, verify that the first deployment updates the existing script rather than creating a duplicate.

### Monorepo Note

The deploy workflow is designed for single-script repositories (micro-repo mode). It finds the first `.sh` file with a `SCRIPT_VERSION` constant and deploys that.

If you are using monorepo mode with multiple scripts, the deploy workflow will need to be adapted. Some options:

- **One workflow per script**: Duplicate the workflow with different path filters so each script has its own deployment trigger.
- **Config file mapping**: Add a `.jamf-deploy.json` that maps script filenames to Jamf Pro script names, and modify the workflow to read it.
- **Changed-file detection**: Use a step that compares the merge diff to determine which scripts changed, then deploy only those.

For most teams starting out, the single-script micro-repo approach is the simplest path.

### Deployment Summary

After each deployment, the workflow posts a summary to the Actions run:

```
## Deployment Summary

Script:  my_awesome_script
Version: 1.0.0
Action:  create
Commit:  abc1234
```

---

## Step 8: Version Updates

When you make changes to your script, use `bump-version` to keep everything in sync:

```bash
# Bump and review manually
bump-version patch "Fixed permission check"

# Or bump and commit in one step
bump-version patch "Fixed permission check" [[2026-03-23]]
```

`bump-version` updates the version in all of these locations at once:

- Script header (`# VERSION:`)
- Script constant (`readonly SCRIPT_VERSION=`)
- Script changelog (inline `# CHANGELOG`)
- `README.md` or `{script_name}_README.md` (version and last updated date, if it exists)
- `CHANGELOG.md` or `{script_name}_CHANGELOG.md` (new version entry, if it exists)
- `build-info.json` or `build-info.plist` (if using munkipkg)

Files that don't exist are skipped gracefully. In a monorepo without per-script scaffolding, only the script itself is updated.

### Monorepo Usage

In a monorepo with multiple scripts, pass the script name explicitly:

```bash
# Bump each script individually
bump-version install_app.sh patch "Fixed permission check" --commit
bump-version remove_app.sh minor "Added logging" --commit
```

Each `--commit` creates a separate, atomic commit for that script's version bump. Other uncommitted changes in the repo are left untouched.

Then push, open a PR, and the cycle repeats.

---

## The Full Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                     YOUR MACHINE                            │
│                                                             │
│  1. shikomi my_script     Scaffold the project              │
│  2. Write your logic      Implement and test                │
│  3. git commit            Pre-commit hooks validate         │
│          │                (Gitleaks + ShellCheck)            │
│          │                                                  │
│          │  BLOCKED if secrets or lint errors found          │
│          ▼                                                  │
│  4. git push              Push to remote branch             │
└──────────┬──────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│                      GITHUB                                 │
│                                                             │
│  5. Pull Request          CI validation runs                │
│          │                (ShellCheck + version check +      │
│          │                 Gitleaks)                         │
│          │                                                  │
│          │  BLOCKED if CI fails                              │
│          ▼                                                  │
│  6. Review + Approve      Human review gate                 │
│          │                                                  │
│          │  BLOCKED if not approved                          │
│          ▼                                                  │
│  7. Merge to main         Triggers deployment               │
│          │                                                  │
└──────────┬──────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│                     JAMF PRO                                │
│                                                             │
│  8. deploy-to-jamf.yml    Authenticates via OAuth           │
│                           Creates or updates script         │
│                           Posts deployment summary           │
│                                                             │
│  ✓ Script in Jamf Pro matches your source of truth          │
└─────────────────────────────────────────────────────────────┘
```

---

## Summary

Every script that reaches Jamf Pro has passed through:

1. **Local validation** (pre-commit hooks on your machine)
2. **CI validation** (GitHub Actions on the pull request)
3. **Human review** (pull request approval)
4. **Automated deployment** (API-driven, versioned, auditable)

No manual uploads. No copy-paste errors. No hardcoded secrets. The repository is the single source of truth for what runs on your fleet.
