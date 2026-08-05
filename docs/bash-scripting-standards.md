# Bash Scripting Standards

These standards apply to all bash scripts in our IT automation repositories, regardless of how they were created. Use this document as a checklist when writing scripts manually.

[Shikomi](#using-shikomi) is our recommended scaffolding tool. It generates fully compliant scripts automatically, so you don't have to apply these rules by hand.

---

## What Applies When

Standards fall into two categories depending on context.

**Script-level requirements** apply every time you write or modify a script, whether it's going into a new repo or an existing one.

**Repo-level requirements** only apply if the repository doesn't already have them. A brand new repo needs all of these set up. An existing repo that already has a `.gitignore`, pre-commit hooks, and branch strategy in place doesn't need them touched — but an existing repo that was set up informally and lacks these still needs them added.

| Requirement | New Repo | Existing Repo (already set up) | Existing Repo (not yet set up) |
|---|---|---|---|
| File header & metadata | Required | Required | Required |
| `SCRIPT_VERSION` constant | Required | Required | Required |
| Logging functions | Required | Required | Required |
| `set -euo pipefail` | Required | Required | Required |
| Variable & function naming | Required | Required | Required |
| Parameter handling | Required | Required | Required |
| Secrets masking | Required | Required | Required |
| `README.md` | Required | Not required | Not required |
| `CHANGELOG.md` | Required | Not required | Not required |
| `.gitignore` | Required | Not required | Required |
| Pre-commit hooks | Required | Not required | Required |
| Feature branch setup | Required | Not required | Required |

---

## Table of Contents

**Script-level**
1. [File Header & Metadata](#file-header--metadata)
2. [Versioning](#versioning)
3. [Variable Naming](#variable-naming)
4. [Functions](#functions)
5. [Logging](#logging)
6. [Error Handling](#error-handling)
7. [Parameter Handling (Jamf)](#parameter-handling-jamf)
8. [Secrets Management](#secrets-management)
9. [Exit Codes](#exit-codes)
10. [Extension Attributes](#extension-attributes)
11. [Bash Compatibility](#bash-compatibility)
12. [Code Style & Linting](#code-style--linting)

**Repo-level (new repos only)**

13. [Git Workflow](#git-workflow)
14. [Documentation](#documentation)

**Tooling**

15. [Using Shikomi](#using-shikomi)

---

## File Header & Metadata

Every script must begin with a metadata block that identifies the script, its version, author, and changelog history.

### Regular Scripts

```bash
#!/bin/bash

################################################################################
# SCRIPT:      script_name.sh
# VERSION:     1.0.0
# AUTHOR:      First Last
# EMAIL:       first.last@example.com
# DATE:        YYYY-MM-DD
# Description: One-line description of what this script does
#
################################################################################
# PARAMETERS:
#   $4: Parameter Label
#   $5: Another Parameter
################################################################################
# CHANGELOG
# 1.0.0 - YYYY-MM-DD - Initial release
################################################################################

# --- Script Metadata ---
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="script_name"
# JAMF_NAME: script_name (Parameters Required)
```

The `# JAMF_NAME:` line is **optional**. Include it when the script's display name in Jamf Pro should differ from the filename — most commonly to append `(Parameters Required)` as a warning to techs that parameters must be configured before use. The deploy pipeline reads this field and uses it as the Jamf lookup name; if absent, the filename (minus `.sh`) is used.

```bash
# With no custom name — Jamf name will be "install_app"
# (no JAMF_NAME line needed)

# With parameters required — Jamf name will be "install_app (Parameters Required)"
# JAMF_NAME: install_app (Parameters Required)
```

> **Lifecycle warning — removing JAMF_NAME:** If you later remove the `# JAMF_NAME:` line (e.g. the script no longer requires parameters), the pipeline will look up the script by filename and not find the existing Jamf entry. It will create a duplicate, leaving the old `(Parameters Required)` entry as a stale orphan that policies may still reference.
>
> Before removing `# JAMF_NAME:` from a script:
> 1. Manually rename the script in Jamf Pro to match the filename (minus `.sh`)
> 2. Update any policies referencing the old name
> 3. Then remove the `# JAMF_NAME:` line and merge — the pipeline will find and update the renamed entry correctly

### Extension Attributes

```bash
#!/bin/bash

##################################################################
# SCRIPT:         check_something_ea.sh
# VERSION:        1.0.0
# DESCRIPTION:    Extension Attribute for Jamf Pro inventory reporting
#
# AUTHOR:         First Last
# EMAIL:          first.last@example.com
##################################################################
#
# History
# 1.0.0 - YYYY-MM-DD - Initial release
#
##################################################################

readonly SCRIPT_VERSION="1.0.0"
```

**Requirements:**
- The `# VERSION:` comment and `readonly SCRIPT_VERSION` constant must always match
- The `CHANGELOG` section in the header must be updated with every version bump
- All parameters must be listed in the `PARAMETERS` block
- Add `# JAMF_NAME:` when the Jamf display name should differ from the filename (e.g. `(Parameters Required)` suffix)

> **Shikomi:** Generates this header automatically using your git config for author and email.

---

## Versioning

All scripts use **Semantic Versioning** (MAJOR.MINOR.PATCH).

| Bump Type | When to Use | Example |
|---|---|---|
| `patch` | Bug fixes, no behavior change | `1.0.0` → `1.0.1` |
| `minor` | New features, backward-compatible | `1.0.1` → `1.1.0` |
| `major` | Breaking changes | `1.1.0` → `2.0.0` |

### Version Locations

Every script version must be consistent across these locations:

**Always (script-level):**
1. `# VERSION:     X.Y.Z` in the script header comment
2. `readonly SCRIPT_VERSION="X.Y.Z"` in the script body
3. `# X.Y.Z - YYYY-MM-DD - Description` in the script's CHANGELOG section

**New repos only (repo-level):**

4. `**Version:** X.Y.Z` in `README.md`
5. `## [X.Y.Z] - YYYY-MM-DD` in `CHANGELOG.md`

**Never edit version numbers manually.** Keeping multiple locations in sync by hand is error-prone.

> **Shikomi / bump-version:** Use `bump-version` to update all applicable locations atomically.
>
> ```bash
> bump-version patch "Fixed permission check"
> bump-version minor "Added retry logic"
> bump-version major "Changed parameter order"
>
> # Bump and commit in one step
> bump-version patch "Fixed permission check" --commit
>
> # In a monorepo, specify the script file
> bump-version my_script.sh patch "Fixed permission check" --commit
> ```

---

## Variable Naming

### Global / Configuration Variables

Use `UPPERCASE_WITH_UNDERSCORES`. Declare immutable constants as `readonly`.

```bash
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="my_script"
readonly LOG_FILE="/var/log/${SCRIPT_NAME}.log"

APP_NAME="${4:-}"
TARGET_DEPT="${5:-}"
```

### Local Variables (inside functions)

Use `lowercase_with_underscores` and always declare with `local`.

```bash
function do_something() {
    local file_path="/tmp/output.txt"
    local result=""
    ...
}
```

### Standard System Variables

Use these patterns when you need common macOS system values. Only include variables your script actually uses.

```bash
SERIAL_NUMBER="$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')"
LOGGED_IN_USER="$(stat -f%Su /dev/console)"
COMPUTER_NAME="$(scutil --get ComputerName)"
OS_VERSION="$(sw_vers -productVersion)"
MODEL_IDENTIFIER="$(sysctl -n hw.model)"
PRIMARY_IP="$(ipconfig getifaddr en0)"
HOSTNAME="$(hostname)"
MAC_ADDRESS="$(ifconfig en0 | awk '/ether/{print $2}')"
CURRENT_USER_HOME="$(eval echo ~"$LOGGED_IN_USER")"
BOOT_VOLUME="$(diskutil info / | awk '/Volume Name/{print $3,$4}')"
TOTAL_RAM_GB="$(sysctl -n hw.memsize | awk '{printf "%.0f", $1/1024/1024/1024}')"
PROCESSOR_NAME="$(sysctl -n machdep.cpu.brand_string)"
```

### Jamf Parameter Variables

Derive the variable name from the parameter label: spaces become underscores, all uppercase, special characters removed.

```bash
# "Target Department" → TARGET_DEPARTMENT
TARGET_DEPARTMENT="${4:-}"

# "API Key" → API_KEY
API_KEY="${5:-}"
```

---

## Functions

- Name functions with `lowercase_with_underscores`
- Use descriptive, multi-word names — no abbreviations
- Declare all variables inside functions with `local`
- Return `0` for success, `1` for failure

```bash
function check_requirements() {
    local required_tool="$1"

    if ! command -v "$required_tool" &> /dev/null; then
        log_error "Required tool not found: $required_tool"
        return 1
    fi
    return 0
}
```

---

## Logging

All scripts must use the following standard logging functions. Copy this block verbatim.

`local` is declared separately from the assignment to satisfy shellcheck SC2155: combining `local var="$(command)"` masks the exit code of the command substitution. Declare first, then assign.

```bash
# --- Logging Setup ---
LOG_FILE="/var/log/${SCRIPT_NAME}.log"
function log()         { local msg; msg="[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*";    echo "$msg" >&2; echo "$msg" >> "$LOG_FILE" 2>/dev/null; }
function log_warn()    { local msg; msg="[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $*";    echo "$msg" >&2; echo "$msg" >> "$LOG_FILE" 2>/dev/null; }
function log_error()   { local msg; msg="[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*";   echo "$msg" >&2; echo "$msg" >> "$LOG_FILE" 2>/dev/null; }
function log_success() { local msg; msg="[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $*"; echo "$msg" >&2; echo "$msg" >> "$LOG_FILE" 2>/dev/null; }
```

### Log Format

```
[YYYY-MM-DD HH:MM:SS] LEVEL: message
```

Example:
```
[2026-04-28 09:15:32] INFO: Starting my_script v1.2.0...
[2026-04-28 09:15:33] INFO: Config: Target Dept [TARGET_DEPT]: Engineering
[2026-04-28 09:15:34] SUCCESS: Task completed successfully
```

### Rules

- All output goes to **stderr** and the **log file** — never to stdout (except EA output, see [Extension Attributes](#extension-attributes))
- Log all configuration values at startup so each run is fully reproducible from logs
- **Never log secret values** — use `*******` as a placeholder

```bash
log "Starting $SCRIPT_NAME v$SCRIPT_VERSION..."
log "Config: App Name [APP_NAME]: $APP_NAME"
log "Config: API Key [API_KEY]: ******* (1Password)"
```

> **Shikomi:** Includes the logging block and `SCRIPT_NAME`/`LOG_FILE` setup automatically.

---

## Error Handling

### Safe Mode

Place this immediately after the header block in every script:

```bash
set -euo pipefail
```

| Option | Effect |
|---|---|
| `-e` | Exit immediately on any command failure |
| `-u` | Treat unset variables as errors |
| `-o pipefail` | Propagate errors through pipes |

> **Exception — Extension Attributes:** Do not use `set -e` in EA scripts. If any command fails under `set -e`, the script exits without printing `<result>...</result>`. Jamf either errors or silently retains the stale inventory value — both are worse than getting a graceful "Not Available". EA scripts should use `set -uo pipefail` and handle errors defensively, ensuring the `<result>` line always executes.

### Glob Safety

When iterating over file patterns, enable `nullglob` to handle empty matches without errors:

```bash
shopt -s nullglob
for file in *.sh; do
    process "$file"
done
```

### Conditional Checks

```bash
if [[ ! -f "$SCRIPT_FILE" ]]; then
    log_error "Script file not found: $SCRIPT_FILE"
    exit 1
fi
```

---

## Parameter Handling (Jamf)

Jamf Pro passes script parameters in positions `$4` through `$11`. Positions `$1`–`$3` are reserved by Jamf and must not be used.

### Standard Pattern

```bash
# Assign with an empty default to avoid unbound variable errors under set -u
APP_NAME="${4:-}"

# Log configuration at startup
log "Config: App Name [APP_NAME]: $APP_NAME"
```

### Parameters with Defaults

```bash
RETRY_COUNT="${5:-3}"
TIMEOUT_SECONDS="${6:-30}"
```

### Required Parameters

```bash
APP_NAME="${4:-}"
if [[ -z "$APP_NAME" ]]; then
    log_error "Parameter 4 (App Name) is required but was not provided."
    exit 1
fi
```

### Header Documentation

All parameters must be documented in the script header's `PARAMETERS` block:

```bash
################################################################################
# PARAMETERS:
#   $4: App Name        - Name of the application to install
#   $5: Retry Count     - Number of retry attempts (default: 3)
#   $6: Timeout Seconds - Timeout per attempt in seconds (default: 30)
################################################################################
```

---

## Secrets Management

**Never hardcode secrets.** Use one of the three approved methods below, in order of preference.

### 1. 1Password CLI (Recommended)

```bash
if command -v op &> /dev/null && op account list &> /dev/null 2>&1; then
    API_KEY="$(op read 'op://Vault/Item/field' 2>/dev/null || echo "${4}")"
else
    API_KEY="${4}"  # Fallback to Jamf parameter
fi

log "Config: API Key [API_KEY]: ******* (1Password)"
```

### 2. Local Secrets File (`~/.jamf_secrets`)

For local development only. The file is sourced at runtime and must never be committed.

```bash
if [[ -f "$HOME/.jamf_secrets" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.jamf_secrets"
fi

log "Config: API Key [API_KEY]: ******* (local secrets)"
```

Format of `~/.jamf_secrets`:
```bash
API_KEY="actual_value_here"
```

### 3. Jamf Parameter (Manual Delivery)

The secret is delivered via a Jamf script parameter. No local storage required.

```bash
API_KEY="${4:-}"
log "Config: API Key [API_KEY]: *******"
```

### Rules

- All secrets logged as `*******` regardless of source — no exceptions
- Never store secrets in CLAUDE.md, README.md, or any committed file

---

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | General error (missing file, invalid input, unmet requirement) |

Functions use `return 0` / `return 1` with the same convention.

```bash
function check_os_version() {
    local minimum="$1"
    local current
    current="$(sw_vers -productVersion)"

    if [[ "$(printf '%s\n' "$minimum" "$current" | sort -V | head -n1)" != "$minimum" ]]; then
        log_error "Requires macOS $minimum or later. Found: $current"
        return 1
    fi
    return 0
}
```

---

## Extension Attributes

Extension Attributes (EAs) are Jamf Pro inventory reporting scripts with strict output requirements.

### Safe Mode Exception

EAs use `set -uo pipefail` instead of the standard `set -euo pipefail`. The `-e` flag is intentionally omitted.

If `-e` is present and any command fails, the script exits before printing `<result>...</result>`. Jamf interprets this as an error or retains the stale inventory value — neither is acceptable. Instead, handle errors defensively and guarantee the result line always executes:

```bash
set -uo pipefail

# Wrap the main logic so a failure falls through to a default
RESULT=""
RESULT="$(some_command 2>/dev/null)" || RESULT="Not Available"
RESULT="${RESULT:-Not Available}"

echo "<result>${RESULT}</result>"
```

### Output Format

The **only** stdout output must be:

```bash
echo "<result>${RESULT}</result>"
```

All other output must go to stderr via the logging functions or `>&2`. Jamf reads stdout to populate inventory — any extra output will break the EA.

### Handling Missing Values

Always set a fallback before the result line so Jamf never receives an empty value:

```bash
RESULT="${RESULT:-Not Available}"
echo "<result>${RESULT}</result>"
```

### Naming Convention

EA scripts must be suffixed with `_ea.sh`:

```
check_disk_space_ea.sh
crowdstrike_version_ea.sh
filevault_status_ea.sh
```

### Local Testing

```bash
./check_something_ea.sh
# Expected output: <result>VALUE</result>
```

---

## Bash Compatibility

All scripts must be compatible with **bash 3.2+**, which is the version bundled with macOS.

### Do Not Use

```bash
declare -A MY_MAP       # Associative arrays — not supported in bash 3.2
echo "${var,,}"         # Lowercase expansion — not supported in bash 3.2
echo "${var^^}"         # Uppercase expansion — not supported in bash 3.2
local -r CONSTANT="x"  # local readonly — not supported in bash 3.2
```

### Use These Instead

```bash
# Indexed arrays instead of associative
MY_ARRAY=("value1" "value2")

# tr for case conversion
echo "$var" | tr '[:upper:]' '[:lower:]'
echo "$var" | tr '[:lower:]' '[:upper:]'

# readonly at global scope; plain local inside functions
readonly GLOBAL_CONSTANT="value"

function my_func() {
    local local_var="value"
}
```

### Shebang

```bash
#!/bin/bash
```

Use `#!/bin/zsh --no-rcs` only when the script has an explicit zsh requirement. Document why in the header.

---

## Code Style & Linting

### ShellCheck

All scripts must pass ShellCheck at warning severity before being committed:

```bash
shellcheck --severity=warning my_script.sh
```

Install ShellCheck: `brew install shellcheck`

### Filename Conventions

| Script Type | Convention | Example |
|---|---|---|
| Regular script | `snake_case.sh` | `install_cyberhaven.sh` |
| Extension Attribute | `snake_case_ea.sh` | `crowdstrike_status_ea.sh` |

Filenames must be lowercase with underscores — no camelCase, no spaces, no hyphens. By default, the deploy pipeline uses the filename (minus `.sh`) as the script's display name in Jamf Pro.

To override the Jamf display name without renaming the file, add a `# JAMF_NAME:` line to the script header (see [File Header & Metadata](#file-header--metadata)). The most common use is appending `(Parameters Required)` to signal to techs that parameters must be set.

> **Existing scripts:** If a script already exists in Jamf Pro under a different name (e.g. camelCase, or with a `(Parameters Required)` suffix), add a `# JAMF_NAME:` header matching the existing Jamf name rather than renaming the script in Jamf — renaming in Jamf risks breaking policy references. See the GitOps rollout guide, Phase 0.5.

### Style Rules

| Rule | Standard |
|---|---|
| Indentation | 4 spaces — no tabs |
| Line endings | LF (Unix) |
| Trailing whitespace | Not allowed |
| End of file | Single newline |
| Variable expansions | Always double-quote: `"$VAR"` |
| Conditionals | Use `[[ ]]` not `[ ]` |
| Command substitution | Use `$()` not backticks |

---

## Git Workflow

> **Only required if not already in place.** A new repo needs all of this configured. An existing repo that already has a branching strategy, `.gitignore`, and pre-commit hooks doesn't need them changed. An existing repo that lacks them needs them added — check the "What Applies When" table at the top of this document.

### Branching

Each script gets its own feature branch during development:

```
feature/script_name
```

### Commit Messages

```bash
# Initial script addition
git commit -m "Add script_name script"

# Version bumps (generated by bump-version --commit)
git commit -m "chore: bump version to 1.2.0 — Fixed permission check"
```

### .gitignore

New repositories must block these files:

```gitignore
# macOS
.DS_Store
.AppleDouble

# Editor
.vscode/
.idea/
*.swp

# Secrets — never commit these
.env
.jamf_secrets
secrets.sh
*.p8
*auth*.json
token.json

# Binaries
*.dmg
*.zip
*.tar.gz
*.pkg
```

### Pre-commit Hooks

New repositories must have pre-commit hooks configured. The **enhanced** set is recommended:

| Check | What It Does |
|---|---|
| betterleaks | Blocks secrets from being committed |
| shellcheck | Lints scripts at warning severity |
| trailing-whitespace | Removes trailing spaces |
| end-of-file-fixer | Ensures newline at end of file |
| check-yaml | Validates YAML syntax |
| check-added-large-files | Blocks files over 1 MB |
| check-merge-conflict | Detects unresolved merge conflict markers |
| detect-private-key | Blocks private key files |

Install pre-commit: `brew install pre-commit`, then `pre-commit install` in the repo root.

> **Shikomi:** Generates `.gitignore` and configures pre-commit hooks automatically. Use `--hooks enhanced` for the full set.

---

## Documentation

> **New repos only.** If you're adding a script to an existing repository, update the existing docs rather than creating new ones — or omit if the repo doesn't use this structure.

Every new repository must include a `README.md` and `CHANGELOG.md`.

### README.md Structure

- Title and metadata table (version, author, last updated)
- Description
- Static Configuration Variables table (names and descriptions)
- Jamf Parameters table (position, label, description, default)
- Local testing instructions
- Versioning notes

### CHANGELOG.md Structure

Follows [Keep a Changelog](https://keepachangelog.com) format:

```markdown
## [1.2.0] - 2026-04-28

### Added
- Retry logic for network failures

### Fixed
- Permission check on managed devices
```

### Inline Comments

Comments explain *why*, not *what*:

```bash
# Bad:  # Increment counter
# Good: # Retry up to 3 times to handle transient network failures
```

> **Shikomi:** Generates `README.md` and `CHANGELOG.md` at scaffold time. **bump-version** keeps them in sync — never edit version numbers in them manually.

---

## Using Shikomi

Shikomi is our script scaffolding tool. It generates a fully compliant script, README, CHANGELOG, .gitignore, and pre-commit hooks in one command — so you don't have to apply this document by hand.

**Strongly recommended for all new scripts.** Write from scratch only when Shikomi doesn't fit (e.g. non-shell scripts, one-off tools not intended for MDM deployment).

```bash
# Standalone script (new repo)
shikomi my_script --auto --claude y

# Script in an existing monorepo (creates a feature branch, skips repo-level setup)
shikomi my_script --auto --claude y --branch y

# Extension Attribute
shikomi check_something --auto --template ea --static-vars "1,2,4" --claude y

# Full new repo setup: GitHub Actions + Jamf deploy workflow + enhanced hooks
shikomi my_script --auto --claude y --workflow y --deploy-workflow y --hooks enhanced --github y
```

### Flag reference

| Flag | Values | What it does |
|---|---|---|
| `--auto` | — | Skips all interactive prompts; uses defaults for any unset flags |
| `--template` | `regular` \| `ea` | Script type: `regular` for management scripts, `ea` for Extension Attributes |
| `--ea-suffix` | `y` \| `n` | Appends `_ea` to the script filename when using the EA template (default: y) |
| `--static-vars` | `1,2,4` / `none` | Injects numbered standard macOS variables (serial number, username, etc.) into the script |
| `--params-file` | path to JSON | Loads Jamf parameter definitions from a JSON file instead of prompting |
| `--no-params` | — | Skips parameter collection entirely |
| `--branch` | `y` \| `n` | Creates a feature branch in monorepo mode (default: y) |
| `--scaffolding` | `y` \| `n` | Generates a per-script README and CHANGELOG in monorepo mode |
| `--hooks` | `basic` \| `enhanced` \| `none` | Pre-commit hook level: `basic` checks secrets; `enhanced` adds shellcheck and formatting |
| `--workflow` | `y` \| `n` | Adds a GitHub Actions workflow for shellcheck/lint validation on push |
| `--deploy-workflow` | `y` \| `n` | Adds a GitHub Actions workflow to deploy the script to Jamf Pro on merge |
| `--github` | `y` \| `n` | Creates a private GitHub repo and pushes the initial commit |
| `--claude` | `y` \| `n` | Generates a `CLAUDE.md` with project context and conventions, plus an initial `SESSION_DIARY.md` |

Run `shikomi --help` for the full flag reference.

### What `--claude y` generates

Passing `--claude y` creates two files in the project directory:

**`CLAUDE.md`** — project context for Claude Code, covering:
- Project name, script type, Shikomi version, and creation date
- Shell script conventions (bash 3.2+ compatibility, shellcheck, shebang, logging functions, exit codes)
- Versioning rules and the requirement to always use `bump-version`
- Secret management method (1Password, local secrets file, or none) and any 1Password item references
- Security rules (what the pre-commit hooks block, what must never be committed)
- Extension Attribute guidelines (output format, silence rules, local testing) — only included when `--template ea` is used
- Session diary instructions

**`SESSION_DIARY.md`** — initialized with a first entry recording the scaffolding event (script name, template type, monorepo vs. standalone).

### bump-version

`bump-version` is installed alongside Shikomi. Use it for all version updates.

```bash
bump-version patch "Fixed permission check"
bump-version minor "Added retry logic"
bump-version major "Changed parameter order"
bump-version patch "Fixed permission check" --commit      # bump and commit
bump-version my_script.sh patch "Fix" --commit            # monorepo
```

---

## Quick Reference

| Task | New Repo | Existing Repo |
|---|---|---|
| Scaffold a script | `shikomi my_script --auto --claude y` | `shikomi my_script --auto --claude y --branch y` |
| Scaffold an EA | `shikomi check_x --auto --template ea --claude y` | Same with `--branch y` |
| Bump a version | `bump-version patch "description" --commit` | Same |
| Lint a script | `shellcheck --severity=warning script.sh` | Same |
| Test an EA locally | `./check_something_ea.sh` | Same |

---

*Last updated: 2026-05-01*
