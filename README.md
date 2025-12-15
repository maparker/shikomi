# Shikomi🔪

**Smart macOS Script Generator for MDM Automation**

Shikomi is an intelligent script scaffolding tool that generates production-ready macOS management scripts with versioning, Git workflows, and best practices built-in. Named after the Japanese culinary term for preparation and mise en place - the foundation of great execution.

---

## Features

[*] **Interactive Script Generation**
- Guided wizard for parameter collection
- Support for MDM parameters ($4-$11 for Jamf Pro)
- Built-in secrets management via `~/.jamf_secrets`
- Standard macOS variable library (serial number, logged in user, etc.)

[+] **Production-Ready Output**
- Semantic versioning (SemVer) built-in
- Automatic README and CHANGELOG generation
- Version bumping utility included
- Security checks via pre-commit hooks

[#] **Security First**
- Gitleaks integration to prevent secret commits
- Smart secret detection and masking
- 1Password CLI integration support
- Configurable `.gitignore` for sensitive files

[~] **Git Workflow Intelligence**
- Monorepo and micro-repo modes
- Feature branch creation
- GitHub integration via `gh` CLI
- Optional GitHub Actions for CI/CD

---

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/shikomi.git
cd shikomi

# Make scripts executable
chmod +x shikomi.sh bump_version.sh add_security_tools.sh

# Optional: Add to PATH
echo 'export PATH="$PATH:$HOME/Documents/Code/shikomi"' >> ~/.zshrc
source ~/.zshrc
```

### Basic Usage

```bash
# Create a new script
./shikomi.sh my_awesome_script

# Follow the interactive prompts:
# 1. Define MDM parameters ($4-$11)
# 2. Add static configuration variables
# 3. Select standard macOS variables
```

### Example Session

```bash
$ ./shikomi.sh install_app

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

[✓] Script generated: install_app.sh (v1.0.0)
```

---

## Core Components

### 1. `shikomi.sh` (v1.0.0)
Main script generator with intelligent wizards for:
- MDM parameter collection
- Static configuration variables
- Standard macOS variable selection
- Secrets management setup

**Version info:**
```bash
./shikomi.sh --version  # Show version
./shikomi.sh --help     # Show usage
```

### 2. `bump_version.sh` (v1.0.0)
Semantic version management utility:
```bash
# Auto-detect script and bump version
./bump_version.sh patch "Fixed bug in user detection"
./bump_version.sh minor "Added notification support"
./bump_version.sh major "Breaking: Changed API interface"

# Or specify script explicitly
./bump_version.sh my_script.sh patch "Bug fix"
```

### 3. `add_security_tools.sh` (v1.0.0)
Security tooling setup for repositories:
- Installs Gitleaks for secret scanning
- Configures pre-commit hooks
- Sets up GitHub Actions workflows
- Adds security-focused `.gitignore` rules

**Version info:**
```bash
./add_security_tools.sh --version  # Show version
./add_security_tools.sh --help     # Show usage
```

---

## Standard macOS Variables Library

Sabrage includes 12 pre-configured macOS system variables:

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
#!/bin/zsh

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
if [[ -f "$HOME/.jamf_secrets" ]]; then
    source "$HOME/.jamf_secrets"
fi

# --- Static Configuration ---
SERIAL_NUMBER="$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')"

# --- Configuration (MDM Parameters) ---
APP_NAME="${4:-"Slack"}"

# --- Logging Setup ---
LOG_FILE="/var/log/script_name.log"
function log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# --- Main Logic ---
log "Starting $SCRIPT_NAME v$SCRIPT_VERSION..."
log "Config: App Name [APP_NAME]: $APP_NAME"
log "System: Serial Number: $SERIAL_NUMBER"

# TODO: Add your logic here

log "$SCRIPT_NAME completed successfully"
exit 0
```

---

## Secrets Management

### Setup `~/.jamf_secrets`

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

### In Your Scripts

Sabrage automatically generates secret-aware code:

```bash
# In generated script (when you mark parameter as secret)
API_KEY="${API_KEY:-$LOCAL_API_KEY}"

# Logs show masked values
log "Config: API Key [API_KEY]: ******* (Masked)"
```

---

## Workflow Modes

### Monorepo Mode
When run inside an existing Git repository:
- Creates scripts in current directory
- Offers feature branch creation
- Uses namespaced files (`script_name_README.md`)
- Preserves existing Git history

### Micro-repo Mode
When run outside a Git repository:
- Creates new project directory
- Initializes fresh Git repo
- Optional GitHub repository creation
- Standalone project structure

---

## Advanced Features

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

Automatic secret scanning before commits:
```bash
# .pre-commit-config.yaml
repos:
-   repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
    -   id: gitleaks
```

---

## Requirements

### Required
- macOS (tested on macOS 10.15+)
- Bash/Zsh shell
- Git

### Optional
- [GitHub CLI (`gh`)](https://cli.github.com/) - For GitHub repo creation
- [pre-commit](https://pre-commit.com/) - For security hooks
- [Gitleaks](https://github.com/gitleaks/gitleaks) - For secret scanning

Install optional tools:
```bash
brew install gh pre-commit gitleaks
```

---

## Best Practices

### Script Development Workflow

1. **Generate Script**
   ```bash
   ./shikomi.sh my_feature
   ```

2. **Implement Logic**
   Edit the generated script and add your implementation

3. **Test Locally**
   ```bash
   sudo ./my_feature.sh
   ```

4. **Bump Version**
   ```bash
   ./bump_version.sh patch "Implemented user validation"
   ```

5. **Commit & Push**
   ```bash
   git add .
   git commit -m "feat: add my_feature script"
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

- [ ] **MDM-Agnostic Mode** - Support for Intune, Kandji, Mosyle
- [ ] **Windows Support** - PowerShell script generation
- [ ] **VS Code Extension** - Native IDE integration
- [ ] **Template Library** - Pre-built script templates
- [ ] **Script Testing Framework** - Automated testing utilities
- [ ] **Web UI** - Browser-based script generator

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

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/shikomi/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YOUR_USERNAME/shikomi/discussions)

---

**Made 🔪 by macOS admins, for macOS admins**
