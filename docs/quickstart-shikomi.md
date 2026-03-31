# Shikomi Quick Start

Get from zero to a production-ready, versioned script in 5 minutes.

---

## Install

```bash
# Clone and install
git clone https://github.com/maparker/shikomi.git
cd shikomi
./install.sh

# Add to PATH (if not already)
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.zshrc
source ~/.zshrc
```

This installs two commands to your PATH:
- **`shikomi`** — the script generator
- **`bump-version`** — the version management utility

Verify both are available:
```bash
shikomi --version
bump-version --version
```

### Install Optional Tools

```bash
brew install pre-commit gh gitleaks 1password-cli
```

---

## Create Your First Script

### Option A: Interactive Wizard

```bash
shikomi my_first_script
```

The wizard will prompt you through each step:

### 1. Choose a Template

```
What type of script do you want to create?
  1) Regular Script     - Full-featured automation
  2) Extension Attribute - Jamf inventory reporting
Selection (1/2) [1]:
```

### 2. Define Jamf Pro Parameters ($4 through $11)

```
--- Parameter 4 ---
Label (e.g. 'Target Dept'): App Name
Is this a secret? (y/n): n
Default Local Value: Slack
```

Press Enter on an empty label to stop adding parameters.

### 3. Add Static Variables

```
Select from standard macOS variables:
  1. SERIAL_NUMBER       - Mac serial number
  2. LOGGED_IN_USER      - Currently logged in user
  3. OS_VERSION          - macOS version number
  ...

Selection: 1 2 3
```

### 4. Choose Pre-Commit Hook Level

```
Choose hook level - (b)asic [secrets only] or (e)nhanced [9 checks]? (b/e):
```

- **Basic**: Gitleaks only (secret scanning)
- **Enhanced**: Gitleaks + ShellCheck + 7 quality checks

### 5. Optional GitHub Actions

```
Add GitHub Actions workflow for PR validation (ShellCheck + version checks)? (y/n):
Also add a workflow to deploy scripts to Jamf Pro on merge? (y/n):
```

### Option B: Non-interactive (Skip the Wizard)

```bash
# Fully automated with sensible defaults
shikomi my_first_script --auto

# With Claude Code configuration
shikomi my_first_script --auto --claude y

# EA script with static variables
shikomi check_serial --auto --template ea --static-vars "1,4"
```

Run `shikomi --help` for all available flags.

---

## What You Get

```
my_first_script/
├── my_first_script.sh       # Your script (v1.0.0)
├── README.md                # Auto-generated docs
├── CHANGELOG.md             # Version history
├── .gitignore               # Security-focused rules
├── .pre-commit-config.yaml  # Hook configuration
└── .github/workflows/       # CI/CD (if selected)
```

---

## Make Changes and Bump the Version

```bash
# Edit your script
open my_first_script.sh

# Test it
sudo ./my_first_script.sh

# Bump the version when ready
bump-version patch "Fixed permission check"

# Or bump and commit in one step
bump-version patch "Fixed permission check" --commit
```

---

## Push and Deploy

```bash
# Push your branch
git push -u origin my-branch

# Create a pull request
gh pr create --title "Add my_first_script" --body "Initial implementation"

# After review and merge, deployment to Jamf Pro happens automatically
```

---

## Useful Commands

| Command | What It Does |
|---------|-------------|
| `shikomi my_script` | Scaffold a new script (interactive) |
| `shikomi my_script --auto` | Scaffold with defaults (non-interactive) |
| `shikomi my_script --auto --claude y` | Scaffold with Claude Code config |
| `shikomi --version` | Show Shikomi version |
| `shikomi --help` | Show all flags and examples |
| `bump-version patch "Fix"` | Bump patch version |
| `bump-version minor "Feature"` | Bump minor version |
| `bump-version major "Breaking"` | Bump major version |
| `bump-version patch "Fix" --commit` | Bump and commit in one step |
| `bump-version my_script.sh patch "Fix"` | Bump a specific script (monorepo) |
| `bump-version --version` | Show bump-version version |

---

## Where to Get Help

- **Repository**: https://github.com/maparker/shikomi
- **Issues**: https://github.com/maparker/shikomi/issues
- **Discussions**: https://github.com/maparker/shikomi/discussions
