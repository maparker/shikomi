# Shikomi

**Smart macOS Script Generator for MDM Automation**

Shikomi is an intelligent script scaffolding tool that generates production-ready macOS management scripts with versioning, Git workflows, and best practices built-in. Named after the Japanese culinary term for preparation and mise en place - the foundation of great execution.

---

## Features

[*] **Interactive & Non-interactive Script Generation**
- Guided wizard for parameter collection (interactive mode)
- Full CLI flag support for automation (`--auto`, `--template`, `--params-file`, etc.)
- Support for MDM parameters ($4-$11 for Jamf Pro)
- Multiple secret storage methods (1Password, file-based, or manual)
- Built-in secrets management with 1Password CLI integration
- Standard macOS variable library (serial number, logged in user, etc.)

[+] **Production-Ready Output**
- Semantic versioning (SemVer) built-in
- Automatic README and CHANGELOG generation
- Version bumping utility included
- Security checks via pre-commit hooks

[#] **Security First**
- Two-tier pre-commit hooks (basic: secrets only, enhanced: 9 checks)
- Gitleaks integration to prevent secret commits
- ShellCheck linting for script quality (enhanced mode)
- Smart secret detection and masking
- 1Password CLI integration support
- Configurable `.gitignore` for sensitive files

[~] **Git Workflow Intelligence**
- Monorepo and micro-repo modes
- Feature branch creation
- GitHub integration via `gh` CLI
- Optional GitHub Actions for version validation
- Optional GitHub Actions workflow to deploy scripts to Jamf Pro via API on merge

[>] **Claude Code Integration**
- Optional `CLAUDE.md` generation with project-specific conventions
- Initialized `SESSION_DIARY.md` for session tracking
- Template-aware: includes EA guidelines, secret method, versioning rules
- In monorepo mode, generates at repo root only if files don't exist

---

## Quick Start

### Installation

#### Option 1: Install to PATH (Recommended)

```bash
# Clone the repository
git clone https://github.com/maparker/shikomi.git
cd shikomi

# Run the installer (installs to ~/.local/bin)
./install.sh

# Or for system-wide installation (requires sudo)
sudo ./install.sh --system

# Add ~/.local/bin to PATH if not already (for user installation)
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.zshrc
source ~/.zshrc
```

The installer adds two commands to your PATH:
- **`shikomi`** — the script generator
- **`bump-version`** — the version management utility (used from any project directory)

Verify both are available:
```bash
shikomi --version
bump-version --version
```

**Updating Shikomi:**
```bash
cd /path/to/shikomi
./install.sh --update
```

The update command will:
- Show current installed versions
- Pull latest changes from git (if available)
- Reinstall to the same location (user or system)
- Show new versions after update

> **Note:** If you downloaded Shikomi as a ZIP file (instead of `git clone`), the update command won't automatically fetch new code. To update:
> 1. Download the latest ZIP from GitHub
> 2. Extract and replace your existing files
> 3. Run `./install.sh --update` to reinstall
>
> For automatic updates, use `git clone` instead of ZIP download.

#### Option 2: Run from Repository

```bash
# Clone the repository
git clone https://github.com/maparker/shikomi.git
cd shikomi

# Make scripts executable
chmod +x shikomi.sh add_security_tools.sh

# Note: shikomi.sh sources lib/*.sh at runtime — keep the lib/ directory alongside it

# Run shikomi directly
./shikomi.sh my_awesome_script

# bump-version can also be run directly from the repo
./bump-version.sh my_script.sh patch "Fixed bug"
```

> **Note:** Option 1 (install to PATH) is strongly recommended. It makes both `shikomi` and `bump-version` available system-wide, and generated project documentation references them as PATH commands.

### Basic Usage (Interactive)

```bash
# Create a new script with the interactive wizard
shikomi my_awesome_script

# Follow the interactive prompts:
# 1. Define MDM parameters ($4-$11)
# 2. Add static configuration variables
# 3. Select standard macOS variables
# 4. Choose pre-commit hook level (basic or enhanced)
```

### Non-interactive Mode (CLI Flags)

Use `--auto` to skip all prompts with sensible defaults, or set individual flags:

```bash
# Fully automated with defaults (regular script, no params, basic hooks)
shikomi my_script --auto

# Automated with Claude Code configuration
shikomi my_script --auto --claude y

# EA script with specific static variables
shikomi check_disk --auto --template ea --static-vars "1,4,11"

# Regular script with parameters from JSON file
shikomi deploy_agent --auto --params-file params.json --workflow y --claude y

# Mix: set template via flag, prompt for everything else
shikomi my_script --template ea
```

**Available flags:**

| Flag | Values | `--auto` default |
|------|--------|-----------------|
| `--auto` | — | Skip all unset prompts |
| `--template` | `regular` / `ea` | `regular` |
| `--ea-suffix` | `y` / `n` | `y` |
| `--scaffolding` | `y` / `n` | `n` (monorepo only) |
| `--params-file` | path to JSON | — |
| `--no-params` | — | implied by `--auto` |
| `--static-vars` | `1,2,4` / `none` | `none` |
| `--branch` | `y` / `n` | `y` |
| `--hooks` | `basic` / `enhanced` / `none` | `basic` |
| `--workflow` | `y` / `n` | `n` |
| `--deploy-workflow` | `y` / `n` | `n` |
| `--github` | `y` / `n` | `n` |
| `--claude` | `y` / `n` | `n` |

**Parameters JSON file schema (`--params-file`):**

```json
{
  "parameters": [
    { "index": 4, "label": "API Key", "secret": true, "storage": "1password",
      "op_vault": "Private", "op_item": "jamf-my-script", "op_field": "api_key" },
    { "index": 5, "label": "Target Dept", "secret": false, "default": "Engineering" }
  ]
}
```

Parsed with `plutil` (stock macOS) — no python3 or jq dependency.

### Example Session (Interactive)

```bash
$ shikomi install_app

==============================================
   macOS Script Generator (Monorepo Mode)
==============================================

--- Parameter 4 ---
Label (e.g. 'Target Dept'): App Name
Is this a secret? (y/n): n
Default Local Value: Slack

--- Parameter 5 ---
Label (e.g. 'Target Dept'): [Enter to skip]

--- Static Configuration Variables ---
Add static configuration variables? (y/n): y

Select from standard macOS variables:
  1. SERIAL_NUMBER       - Mac serial number
  2. LOGGED_IN_USER      - Currently logged in user
  3. COMPUTER_NAME       - Computer name
  4. OS_VERSION          - macOS version number
  ...

Selection: 1 2 4
  Added: SERIAL_NUMBER
  Added: LOGGED_IN_USER
  Added: OS_VERSION

Pre-commit hooks protect against secrets and code quality issues.
Choose hook level - (b)asic [secrets only] or (e)nhanced [9 checks]? (b/e): e
Installing enhanced pre-commit hooks (9 checks)...
✓ Pre-commit hooks installed

[✓] Script generated: install_app.sh (v1.0.0)
```

---

## Core Components

### 1. `shikomi` (v2.0.0)
Main script generator with interactive wizard and non-interactive CLI mode:
- MDM parameter collection
- Static configuration variables
- Standard macOS variable selection
- Secrets management setup (1Password or file-based)
- Claude Code scaffolding (CLAUDE.md + SESSION_DIARY.md)

**Version info:**
```bash
shikomi --version  # Show version
shikomi --help     # Show full usage with all flags
```

### 2. `bump-version` (v1.3.0)
Semantic version management utility:
```bash
# Bump version with change description (explicit script)
bump-version my_script.sh patch "Fixed bug in user detection"
bump-version my_script.sh minor "Added notification support"
bump-version my_script.sh major "Breaking: Changed API interface"

# Bump and commit in one step
bump-version my_script.sh patch "Fixed bug" --commit

# Auto-detect mode (omit the script name)
bump-version patch "Fixed bug in user detection"
```

**Initializing an Existing Script:**
Use `init` to add versioning infrastructure to a script that wasn't created by Shikomi:

```bash
# Add versioning at 1.0.0 (default)
bump-version my_script.sh init "Initial release"

# Start at a specific version
bump-version my_script.sh init "Initial release" 2.1.0

# Initialize and commit in one step
bump-version my_script.sh init "Initial release" --commit
```

`init` injects three things into the target script:
1. `# VERSION:     1.0.0` — into the script header (after `# SCRIPT:` if present, otherwise appended to the existing comment block)
2. A `# CHANGELOG` section (or `# History` for `_ea.sh` scripts) — before the closing header divider
3. `readonly SCRIPT_VERSION="1.0.0"` — immediately after `set -euo pipefail`

**Prerequisite:** The script must contain `set -euo pipefail` (or `set -uo pipefail` for Extension Attributes) for the `readonly SCRIPT_VERSION=` line to be injected automatically. Without it, `init` will warn and you'll need to add the line manually. Once `init` is done, use the normal `patch`/`minor`/`major` commands for all future version bumps.

**Auto-Detect Behavior:**
When no script is specified, `bump-version` finds all `.sh` files in the current directory that contain a `SCRIPT_VERSION` constant (excluding `bump-version.sh` itself) and selects the **most recently modified** one. This means it targets whichever script you were just editing. If multiple versioned scripts are found, a warning lists all candidates and shows which was chosen.

**Monorepo Support:**
`bump-version` automatically resolves the correct README and CHANGELOG for each script:
- Micro-repo: looks for `README.md` and `CHANGELOG.md`
- Monorepo: looks for `{script_name}_README.md` and `{script_name}_CHANGELOG.md`
- If neither exists (monorepo without scaffolding), only the script itself is updated

The `--commit` flag stages only the files that were touched, so you can bump multiple scripts independently without conflicts.

**munkipkg Integration:**
`bump-version` automatically detects and updates munkipkg package versions:
- Searches for `build-info.json` or `build-info.plist` in root, `pkg/`, and `build/` directories
- Updates the version field to match your script version
- Supports both JSON and plist formats
- Keeps scripts and installer packages in perfect sync

```bash
# When you bump a script version, munkipkg build-info is updated automatically
bump-version my_script.sh minor "Added new feature"
# Output: Updating munkipkg version in: pkg/build-info.json
```

### 3. `add_security_tools.sh` (v1.2.0)
Security tooling setup for existing repositories:
- Installs Gitleaks for secret scanning
- Configures pre-commit hooks (basic or enhanced)
- Sets up GitHub Actions workflows (security checks)
- Optional Jamf Pro deploy workflow
- Adds security-focused `.gitignore` rules

**Version info:**
```bash
./add_security_tools.sh --version  # Show version
./add_security_tools.sh --help     # Show usage
```

---

## Script Templates

Shikomi supports multiple script templates:

### 1. Regular Script (Default)
Full-featured automation scripts with:
- Jamf Pro parameters ($4-$11)
- Logging functions (log, log_warn, log_error, log_success)
- Secrets management (1Password or file-based)
- Static configuration variables

**Use for:** Installation, configuration management, user provisioning, automation workflows

### 2. Extension Attribute (EA)
Lightweight inventory reporting scripts with:
- Simple header with version tracking
- Static data collection variables
- Required `<result>VALUE</result>` output format
- No parameters, logging, or secrets management
- Optimized for fast execution

**Use for:** Jamf Pro inventory data collection, application version checking, compliance reporting

### Template Selection

During script generation, you'll be prompted:
```
What type of script do you want to create?
  1) Regular Script     - Full-featured automation
  2) Extension Attribute - Jamf inventory reporting
Selection (1/2) [1]:
```

### Example: Creating an Extension Attribute

```bash
$ shikomi crowdstrike_version
Selection: 2
Add '_ea' suffix? (y/n) [y]: y

# Generated: crowdstrike_version_ea.sh with <result> output format
```

---

## Standard macOS Variables Library

Shikomi includes 12 pre-configured macOS system variables:

| # | Variable | Description |
|---|----------|-------------|
| 1 | `SERIAL_NUMBER` | Mac serial number |
| 2 | `LOGGED_IN_USER` | Currently logged in user |
| 3 | `COMPUTER_NAME` | Computer name from System Preferences |
| 4 | `OS_VERSION` | macOS version number |
| 5 | `MODEL_IDENTIFIER` | Hardware model identifier |
| 6 | `PRIMARY_IP` | Primary network IP address |
| 7 | `HOSTNAME` | Network hostname |
| 8 | `MAC_ADDRESS` | Primary MAC address |
| 9 | `CURRENT_USER_HOME` | Home directory of logged in user |
| 10 | `BOOT_VOLUME` | Name of boot volume |
| 11 | `TOTAL_RAM_GB` | Total RAM in gigabytes |
| 12 | `PROCESSOR_NAME` | CPU processor name |

Simply enter the numbers during script generation to include these variables.

---

## Generated Script Structure

Every generated script includes:

```bash
#!/bin/bash

################################################################################
# SCRIPT:      script_name.sh
# VERSION:     1.0.0
# AUTHOR:      Your Name
# EMAIL:       your.email@company.com
# DATE:        2025-12-07
# Description: Auto-generated description
################################################################################

# --- Script Metadata ---
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="script_name"

# --- Local Development Secrets ---
# This block is for local testing only. On managed endpoints (via Jamf Pro),
# this file will not exist and secrets are delivered through parameters ($4-$11).
if [[ -f "$HOME/.jamf_secrets" ]]; then
    source "$HOME/.jamf_secrets"
fi

# --- Static Configuration ---
SERIAL_NUMBER="$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')"

# --- Configuration (Jamf Parameters) ---
APP_NAME="${4:-"Slack"}"

# --- Logging Setup ---
LOG_FILE="/var/log/script_name.log"
function log() { local msg="[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*"; echo "$msg" >&2; echo "$msg" >> "$LOG_FILE" 2>/dev/null; }
function log_warn() { local msg="[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $*"; echo "$msg" >&2; echo "$msg" >> "$LOG_FILE" 2>/dev/null; }
function log_error() { local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*"; echo "$msg" >&2; echo "$msg" >> "$LOG_FILE" 2>/dev/null; }
function log_success() { local msg="[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $*"; echo "$msg" >&2; echo "$msg" >> "$LOG_FILE" 2>/dev/null; }

# --- Main Logic ---
log "Starting $SCRIPT_NAME v$SCRIPT_VERSION..."
log "Config: App Name [APP_NAME]: $APP_NAME"
log "System: Serial Number: $SERIAL_NUMBER"

# TODO: Add your logic here

log "$SCRIPT_NAME completed successfully"
exit 0
```

---

## Built-in Logging Functions

Every generated script includes enhanced logging functions with severity levels:

### Available Functions

| Function | Severity | Output | Use Case |
|----------|----------|--------|----------|
| `log()` | INFO | stderr + log file | General information and progress updates |
| `log_warn()` | WARN | stderr + log file | Non-critical warnings that don't stop execution |
| `log_error()` | ERROR | stderr + log file | Critical errors requiring attention |
| `log_success()` | SUCCESS | stderr + log file | Successful completion of operations |

### Usage Examples

```bash
# General information logging
log "Starting installation of Slack"
log "Downloading package from https://example.com/slack.dmg"

# Warning for non-critical issues
log_warn "User not logged in, using default settings"
log_warn "Optional dependency not found, skipping feature"

# Error logging (outputs to stderr)
log_error "Failed to download package from URL"
log_error "Insufficient disk space: ${AVAILABLE_SPACE}GB available"

# Success messages for completed operations
log_success "Application installed successfully"
log_success "Configuration file updated"
```

### Log Output Format

All logs include timestamp and severity level:

```
[2026-01-18 14:30:15] INFO: Starting installation of Slack
[2026-01-18 14:30:16] WARN: User not logged in, using default settings
[2026-01-18 14:30:20] ERROR: Failed to download package from URL
[2026-01-18 14:30:25] SUCCESS: Application installed successfully
```

### Filtering Logs

Use grep to filter by severity:

```bash
# Show only errors
grep "ERROR:" /var/log/my_script.log

# Show warnings and errors
grep -E "WARN:|ERROR:" /var/log/my_script.log

# Show only successful operations
grep "SUCCESS:" /var/log/my_script.log

# Count errors
grep -c "ERROR:" /var/log/my_script.log
```

### Log File

All log functions automatically write to both stderr and `/var/log/{script_name}.log`. The log file write is silent if the path is not writable (e.g. running without sudo during local testing).

```bash
# View the log file
cat /var/log/my_script.log

# Follow in real time
tail -f /var/log/my_script.log
```

---

## Secrets Management

Shikomi supports **multiple secret storage methods**, giving you flexibility based on your team's workflow.

### Method 1: 1Password (Recommended for Teams)

When generating a script, Shikomi can integrate with 1Password CLI for secure, team-sharable secrets.

#### Setup 1Password CLI

```bash
# Install 1Password CLI
brew install 1password-cli

# Authenticate (one-time setup)
op account add
```

#### During Script Generation

When you mark a parameter as a secret, you'll see:

```
Where should this secret be stored?
  1) 1Password (recommended for team sharing)
  2) ~/.jamf_secrets (traditional local file)
  3) Skip (configure manually later)
```

Choose option 1 for 1Password integration. Shikomi will:
1. Ask for vault name (default: `Private`)
2. Ask for item name (default: `jamf-{script_name}`)
3. Ask for field name (default: lowercase variable name)
4. Optionally create/update the secret immediately

#### Generated Code

Scripts with 1Password secrets automatically fetch from 1Password at runtime:

```bash
# Fetch from 1Password with fallback to Jamf parameter
if command -v op &> /dev/null && op account list &> /dev/null 2>&1; then
    API_KEY="$(op read 'op://Private/jamf-my_script/api_key' 2>/dev/null || echo "${4}")"
else
    API_KEY="${4}"  # Fallback to Jamf parameter
fi

# Logs show masked values
log "Config: API Key [API_KEY]: ******* (1Password)"
```

#### Benefits of 1Password Integration

- Team-sharable secrets across your organization
- No plaintext files to secure or accidentally commit
- Automatic fallback to Jamf parameters if 1Password unavailable
- Works seamlessly with existing 1Password workflows
- Optional immediate secret creation during script generation

#### Testing 1Password Secrets

```bash
# Test secret retrieval
op read "op://Private/jamf-my_script/api_key"

# Run script with 1Password integration
sudo ./my_script.sh
```

### Method 2: File-Based Secrets (`~/.jamf_secrets`)

For local development or simpler workflows, use traditional file-based secrets:

#### Setup

Create a secrets file for local testing:

```bash
# Create secrets file
cat > ~/.jamf_secrets << 'EOF'
# Local development secrets
LOCAL_API_KEY="your-test-api-key"
LOCAL_API_TOKEN="your-test-token"
EOF

# Secure the file
chmod 600 ~/.jamf_secrets
```

#### Generated Code

Shikomi automatically generates secret-aware code:

```bash
# In generated script (when you mark parameter as secret)
API_KEY="${LOCAL_API_KEY:-${4}}"

# Logs show masked values
log "Config: API Key [API_KEY]: ******* (Masked)"
```

### Method 3: Manual Configuration

Choose option 3 during generation to configure secrets manually later. Shikomi will add TODO comments to guide you.

---

## Workflow Modes

### Monorepo Mode
When run inside an existing Git repository:
- Creates scripts in current directory
- Offers feature branch creation
- Uses namespaced files (`script_name_README.md`)
- Preserves existing Git history
- Generates monorepo-aware deploy workflow (auto-detects changed versioned scripts)

For the full monorepo workflow — including new scripts, updates, legacy migration, and multi-script PRs — see [docs/guide-monorepo-workflow.md](docs/guide-monorepo-workflow.md).

### Micro-repo Mode
When run outside a Git repository:
- Creates new project directory
- Initializes fresh Git repo
- Optional GitHub repository creation
- Standalone project structure

---

## Advanced Features

### munkipkg Integration

Shikomi's `bump-version` utility seamlessly integrates with [munkipkg](https://github.com/munki/munki-pkg) for macOS package creation:

**Automatic Version Synchronization:**
When you bump your script version, `bump-version` automatically updates your munkipkg configuration:
- Detects `build-info.json` (JSON format) or `build-info.plist` (Property List format)
- Searches in multiple locations: root directory, `pkg/`, and `build/`
- Updates the `version` field to match your new script version
- No manual editing of build-info files required

**Example Workflow:**
```bash
# Your project structure
my_installer/
├── my_script.sh
├── pkg/
│   ├── build-info.json
│   └── payload/
└── README.md

# Bump your script version
bump-version patch "Fixed installation bug"

# Output:
# Current version: 1.0.0
# New version: 1.0.1
# Updating munkipkg version in: pkg/build-info.json
# SUCCESS: Version bumped to 1.0.1

# Now build your package with munkipkg
munkipkg pkg/
# Package version automatically matches script version!
```

This ensures your installer package versions always stay in sync with your script versions, eliminating version mismatch issues.

### GitHub Actions Integration

Optionally generate CI/CD workflows:
- Version validation (script vs README)
- ShellCheck linting
- Tag-based releases

```yaml
# Auto-generated .github/workflows/validate-version.yml
name: Validate Version
on:
  pull_request:
    branches: [ main, master ]
  push:
    tags: [ 'v*' ]
```

### Pre-commit Hooks

Shikomi offers **two levels** of pre-commit hooks during project creation:

#### Basic Hooks (Default)
Secret scanning only - lightweight protection:
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
```

#### Enhanced Hooks (Recommended)
Comprehensive security and quality suite with **9 checks**:
```yaml
repos:
  # Secret scanning
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks

  # Shell script linting
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.9.0.6
    hooks:
      - id: shellcheck
        args: [--severity=warning]

  # General checks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace       # Remove trailing spaces
      - id: end-of-file-fixer         # Ensure newline at EOF
      - id: check-yaml                # Validate YAML syntax
      - id: check-added-large-files   # Block files > 1MB
      - id: check-merge-conflict      # Detect conflict markers
      - id: detect-private-key        # Find SSH/GPG keys
```

**During project creation**, you'll be prompted to choose:
```
Choose hook level - (b)asic [secrets only] or (e)nhanced [9 checks]? (b/e):
```

For **existing projects**, use `add_security_tools.sh` to add hooks and optional Jamf Pro deployment

### Claude Code Integration

Shikomi can generate Claude Code configuration files to make your project immediately AI-assistant ready:

```bash
# During interactive wizard, you'll be prompted:
# "Set up Claude Code configuration? (CLAUDE.md + SESSION_DIARY.md) (y/n)"

# Or via CLI flag:
shikomi my_script --auto --claude y
```

**Generated `CLAUDE.md` includes:**
- Project type and shell conventions (bash 3.2+, shellcheck)
- Versioning rules (always use `bump-version`)
- Secret management method chosen during generation
- Security rules (never commit secrets, .gitignore patterns)
- EA-specific guidelines (if Extension Attribute template)
- Session diary instruction for tracking work

**Generated `SESSION_DIARY.md`** is initialized with a first entry documenting what Shikomi created.

**Monorepo behavior:** Files are generated at the repo root. If `CLAUDE.md` or `SESSION_DIARY.md` already exist, they are not overwritten.

For the full integration guide — including global config setup, common scenarios, and troubleshooting — see [docs/guide-claude-code-integration.md](docs/guide-claude-code-integration.md).

---

## Workshop

Attending the **macOS GitOps** workshop? See the [Workshop Preparation Guide](docs/guide-workshop-preparation.md) for what to set up before arriving.

---

## Requirements

### Required
- macOS (tested on macOS 10.15+)
- Bash/Zsh shell
- Git

### Optional
- [1Password CLI (`op`)](https://developer.1password.com/docs/cli/) - For 1Password secrets integration
- [GitHub CLI (`gh`)](https://cli.github.com/) - For GitHub repo creation
- [pre-commit](https://pre-commit.com/) - For security hooks
- [Gitleaks](https://github.com/gitleaks/gitleaks) - For secret scanning

Install optional tools:
```bash
brew install 1password-cli gh pre-commit gitleaks
```

---

## Best Practices

### Script Development Workflow

1. **Generate Script**
   ```bash
   shikomi my_feature
   ```

2. **Implement Logic**
   Edit the generated script and add your implementation

3. **Test Locally**
   ```bash
   sudo ./my_feature.sh
   ```

4. **Bump Version**
   ```bash
   bump-version my_feature.sh patch "Implemented user validation"

   # Or bump and commit in one step
   bump-version my_feature.sh patch "Implemented user validation" --commit
   ```

5. **Push**
   ```bash
   git push
   ```

### Security Guidelines

- [✓] **DO**: Store secrets in `~/.jamf_secrets` or 1Password
- [✓] **DO**: Mark sensitive parameters as secrets
- [✓] **DO**: Use pre-commit hooks
- [X] **DON'T**: Hardcode credentials in scripts
- [X] **DON'T**: Commit `.env` or `*_secrets` files
- [X] **DON'T**: Skip secret detection warnings

---

## Roadmap

- [x] **Non-interactive CLI Mode** - Full flag support for automation (v2.0.0)
- [x] **Claude Code Integration** - Project-aware CLAUDE.md scaffolding (v2.0.0)
- [x] **Monorepo Deploy Workflow** - Auto-detect and deploy changed versioned scripts (v2.0.0)
- [ ] **Extension Attribute Deployment** - Auto-deploy EAs via Jamf Classic API (XML payloads, `_ea.sh` naming convention detection)
- [ ] **Script Testing Framework** - Automated testing utilities
- [ ] **MDM-Agnostic Mode** - Support for Intune, Kandji, Mosyle
- [ ] **Template Library** - Pre-built script templates

---

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Use Shikomi itself to generate your scripts
4. Commit with conventional commits (`feat:`, `fix:`, `docs:`)
5. Push and open a Pull Request

---

## License

MIT License - See [LICENSE](LICENSE) for details

---

## Name Origin

**Shikomi** (仕込み, shee-koh-mee) - A Japanese culinary term meaning "preparation" or "mise en place" - the meticulous prep work that chefs do before service begins. Like this tool, shikomi emphasizes proper preparation, organization, and building the foundation for flawless execution.

---

## Support

- **Issues**: [GitHub Issues](https://github.com/maparker/shikomi/issues)
- **Discussions**: [GitHub Discussions](https://github.com/maparker/shikomi/discussions)

---

**Made 🔪 by macOS admins, for macOS admins**
