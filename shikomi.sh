#!/bin/bash

################################################################################
# SCRIPT:      shikomi.sh
# VERSION:     1.7.1
# AUTHOR:      Matt Parker
# DATE:        2025-12-07
# DESCRIPTION: Smart macOS/MDM Script Generator
#              - Detects if you are in an existing Git Repo (Monorepo mode)
#              - If not, creates a new Repo/Project (Micro-repo mode)
#              - Generates versioned scripts with semantic versioning
#              - Initializes Git + Pre-Commit Hooks + GitHub integration
################################################################################
# CHANGELOG
# 1.7.1 - 2026-03-10 - Multiple fixes: LOG_FILE usage, input validation, CHANGELOG insertion, variable expansion, email fallback
# 1.7.0 - 2026-01-25 - Added EA template support, multi-template generation, stderr logging fix
# 1.6.0 - 2026-01-25 - Added 1Password integration for secret storage with interactive configuration during script generation
# 1.5.4 - 2026-01-19 - Updated bump-version.sh to only modify actual version numbers, not template variables
# 1.5.3 - 2026-01-19 - Fixed version template to prevent generated scripts from inheriting shikomi's version number
# 1.5.2 - 2026-01-19 - Updated the created gitignore file to better prevent committing pkg files.
# 1.5.1 - 2026-01-18 - Added enhanced logging functions to generated scripts
# 1.5.0 - 2026-01-18 - Added munkipkg integration to generated bump-version.sh scripts
# 1.4.3 - 2026-01-09 - Fixed secrets variable
# 1.4.2 - 2026-01-08 - Fixed new script template version (was incorrectly 1.4.1, now correctly 1.0.0)
# 1.4.1 - 2026-01-08 - Changed default shebang
# 1.4.0 - 2026-01-08 - Fix versioning for new script creation
# 1.3.0 - 2026-01-08 - Added interactive prompt for enhanced pre-commit hooks with 9 checks
# 1.2.1 - 2025-12-29 - Fixed readonly variable conflict with SCRIPT_NAME
# 1.2.0 - 2025-12-20 - Changed generated bump_version.sh to bump-version.sh (hyphenated)
# 1.1.0 - 2025-12-20 - Added install.sh for PATH installation support
# 1.0.0 - 2025-12-07 - Initial release as Shikomi (rebranded from script_creator_pro)
################################################################################

# --- Script Metadata ---
readonly SCRIPT_VERSION="1.7.1"
readonly GENERATOR_NAME="shikomi"

# --- 0. Version/Help Check ---
if [[ "$1" == "--version" ]] || [[ "$1" == "-v" ]]; then
    echo "Shikomi v$SCRIPT_VERSION"
    exit 0
fi

if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Shikomi v$SCRIPT_VERSION - Smart macOS/MDM Script Generator"
    echo ""
    echo "Usage: $(basename "$0") <script_name>"
    echo ""
    echo "Options:"
    echo "  -v, --version    Show version"
    echo "  -h, --help       Show this help"
    exit 0
fi

# --- 1. Prerequisites Check ---
if ! command -v gh &> /dev/null; then
    echo "Warning: GitHub CLI ('gh') not installed. Remote repo creation will be skipped."
fi
if ! command -v pre-commit &> /dev/null; then
    echo "Warning: 'pre-commit' not installed. Security hooks will be skipped."
fi

# --- 2. Context Awareness: Detect Existing Git Repo ---
SCRIPT_NAME="$1"

if [[ -z "$SCRIPT_NAME" ]]; then
    echo "Usage: $(basename "$0") <script_name>"
    exit 1
fi

# Validate script name — only allow safe characters for file paths, branches, and repo names
if [[ ! "$SCRIPT_NAME" =~ ^[a-zA-Z0-9_-]+(\.[sS][hH])?$ ]]; then
    echo "Error: Script name must contain only letters, numbers, hyphens, and underscores"
    exit 1
fi

# Clean up extension
SCRIPT_NAME="${SCRIPT_NAME%.sh}"

# Check if we are inside an existing Git Repository
IS_MONOREPO=false
if git rev-parse --is-inside-work-tree &> /dev/null; then
    IS_MONOREPO=true
    REPO_ROOT=$(git rev-parse --show-toplevel)
    echo "=============================================="
    echo "   macOS Script Generator (Monorepo Mode)    "
    echo "=============================================="
    echo "Detected existing Git Repository: $(basename "$REPO_ROOT")"

    # In monorepo, we write to current directory
    PROJECT_DIR="$PWD"
    SCRIPT_PATH="$PROJECT_DIR/${SCRIPT_NAME}.sh"
    README_PATH="$PROJECT_DIR/${SCRIPT_NAME}_README.md"
    CHANGELOG_PATH="$PROJECT_DIR/${SCRIPT_NAME}_CHANGELOG.md"

    # Check if script already exists
    if [[ -f "$SCRIPT_PATH" ]]; then
        echo "Error: Script already exists: $SCRIPT_PATH"
        echo "Use a different name or delete the existing script first"
        exit 1
    fi

    # Safety Check: Are there uncommitted changes?
    if [[ -n $(git status --porcelain) ]]; then
        echo "Error: You have uncommitted changes in this repo."
        echo "   Please commit or stash them before creating a new script."
        exit 1
    fi

    # In monorepo mode, per-script scaffolding (README, CHANGELOG, bump-version) is optional
    GENERATE_SCAFFOLDING=false
    read -rp "Generate per-script README, CHANGELOG, and bump-version.sh? (y/n) [n]: " gen_scaffolding
    if [[ "$gen_scaffolding" =~ ^[Yy] ]]; then
        GENERATE_SCAFFOLDING=true
    fi
else
    echo "=============================================="
    echo "  macOS Script Generator (New Project Mode)  "
    echo "=============================================="
    echo "No existing Git repo detected. Creating new project."

    # In new project, we create a folder
    SCRIPTS_DIR="${JAMF_SCRIPTS_DIR:-$PWD}"
    PROJECT_DIR="$SCRIPTS_DIR/$SCRIPT_NAME"

    if [[ -d "$PROJECT_DIR" ]]; then
        echo "Error: Directory already exists: $PROJECT_DIR"
        exit 1
    fi
    mkdir -p "$PROJECT_DIR"
    SCRIPT_PATH="$PROJECT_DIR/${SCRIPT_NAME}.sh"
    README_PATH="$PROJECT_DIR/README.md"
    CHANGELOG_PATH="$PROJECT_DIR/CHANGELOG.md"
fi

# --- 2. Template Selection ---
echo ""
echo "--- Script Template Selection ---"
echo "What type of script do you want to create?"
echo "  1) Regular Script     - Full-featured automation with parameters, logging, secrets"
echo "  2) Extension Attribute - Simple Jamf inventory reporting (<result> output)"
read -rp "Selection (1/2) [1]: " template_choice
template_choice="${template_choice:-1}"

case "$template_choice" in
    1)
        SCRIPT_TEMPLATE="regular"
        echo "Selected: Regular Script"
        ;;
    2)
        SCRIPT_TEMPLATE="ea"
        echo "Selected: Extension Attribute"
        # For EA scripts, suggest _ea suffix if not present
        if [[ ! "$SCRIPT_NAME" =~ _ea$ ]]; then
            read -rp "Add '_ea' suffix to script name? (y/n) [y]: " add_suffix
            add_suffix="${add_suffix:-y}"
            if [[ "$add_suffix" =~ ^[Yy] ]]; then
                SCRIPT_NAME="${SCRIPT_NAME}_ea"
                SCRIPT_PATH="$PROJECT_DIR/${SCRIPT_NAME}.sh"
                if [ "$IS_MONOREPO" = true ]; then
                    README_PATH="$PROJECT_DIR/${SCRIPT_NAME}_README.md"
                    CHANGELOG_PATH="$PROJECT_DIR/${SCRIPT_NAME}_CHANGELOG.md"
                fi
                echo "Script name updated to: ${SCRIPT_NAME}.sh"
            fi
        fi
        ;;
    *)
        echo "Invalid selection. Defaulting to Regular Script."
        SCRIPT_TEMPLATE="regular"
        ;;
esac
echo ""

echo "Target: $SCRIPT_PATH"

# --- 2. Interactive Wizard ---
declare -a BLOCK_HEADER
declare -a BLOCK_VARIABLES
declare -a BLOCK_LOGGING
declare -a README_ROWS
SECRETS_USED=false
declare -a SECRET_REMINDERS
declare -a ONEPASSWORD_SECRETS  # Track 1Password secret references

# Only collect Jamf parameters for regular scripts
if [[ "$SCRIPT_TEMPLATE" == "regular" ]]; then
    echo "Define Parameters (\$4-\$11). Press [Enter] on Label to finish."
    echo ""

for i in {4..11}; do
    echo "--- Parameter $i ---"
    read -rp "Label (e.g. 'Target Dept'): " param_label
    [[ -z "$param_label" ]] && break

    var_name=$(echo "$param_label" | tr '[:lower:]' '[:upper:]' | tr ' ' '_' | sed 's/[^A-Z0-9_]//g')

    read -rp "Is this a secret? (y/n): " is_secret

    if [[ "$is_secret" =~ ^[Yy] ]]; then
        SECRETS_USED=true
        BLOCK_HEADER+=("#   $var_name (Jamf: \$$i)")

        # Ask where to store the secret
        echo ""
        echo "Where should this secret be stored?"
        echo "  1) 1Password (recommended for team sharing)"
        echo "  2) ~/.jamf_secrets (traditional local file)"
        echo "  3) Skip (configure manually later)"
        read -rp "Choice (1/2/3): " secret_storage

        case "$secret_storage" in
            1)
                # 1Password storage
                echo "1Password Configuration:"
                read -rp "  Vault name [Private]: " op_vault
                op_vault="${op_vault:-Private}"

                read -rp "  Item name [jamf-${SCRIPT_NAME}]: " op_item
                op_item="${op_item:-jamf-${SCRIPT_NAME}}"

                # Convert variable name to lowercase for field name suggestion
                field_suggestion=$(echo "$var_name" | tr '[:upper:]' '[:lower:]')
                read -rp "  Field name [${field_suggestion}]: " op_field
                op_field="${op_field:-${field_suggestion}}"

                OP_REFERENCE="op://${op_vault}/${op_item}/${op_field}"

                # Ask if they want to create the item now
                if command -v op &> /dev/null; then
                    read -rp "  Create/update this secret in 1Password now? (y/n): " create_now
                    if [[ "$create_now" =~ ^[Yy] ]]; then
                        read -rsp "  Enter secret value: " secret_value
                        echo ""

                        # Try to create or edit the item
                        if op item get "$op_item" --vault "$op_vault" &>/dev/null; then
                            echo "  Updating existing item..."
                            op item edit "$op_item" --vault "$op_vault" "${op_field}[password]=$secret_value" &>/dev/null && \
                                echo "  ✓ Secret updated in 1Password" || \
                                echo "  ✗ Failed to update. You'll need to add it manually."
                        else
                            echo "  Creating new item..."
                            op item create --category=password --title="$op_item" --vault="$op_vault" \
                                "${op_field}[password]=$secret_value" &>/dev/null && \
                                echo "  ✓ Secret created in 1Password" || \
                                echo "  ✗ Failed to create. You'll need to add it manually."
                        fi
                    else
                        SECRET_REMINDERS+=("1Password: ${OP_REFERENCE}")
                    fi
                else
                    echo "  Warning: 1Password CLI not installed. Install with: brew install 1password-cli"
                    SECRET_REMINDERS+=("1Password: ${OP_REFERENCE} (install 'op' CLI first)")
                fi

                # Generate 1Password-aware code
                BLOCK_VARIABLES+=("# Fetch from 1Password with fallback to Jamf parameter")
                BLOCK_VARIABLES+=("if command -v op &> /dev/null && op account list &> /dev/null 2>&1; then")
                BLOCK_VARIABLES+=("    ${var_name}=\"\$(op read '${OP_REFERENCE}' 2>/dev/null || echo \"\${${i}}\")\"")
                BLOCK_VARIABLES+=("else")
                BLOCK_VARIABLES+=("    ${var_name}=\"\${${i}}\"  # Fallback to Jamf parameter")
                BLOCK_VARIABLES+=("fi")

                BLOCK_LOGGING+=("log \"Config: $param_label [${var_name}]: ******* (1Password)\"")
                README_ROWS+=("| $var_name | \$$i | \`${OP_REFERENCE}\` (1Password) |")
                ONEPASSWORD_SECRETS+=("${OP_REFERENCE}")
                ;;

            2)
                # Traditional ~/.jamf_secrets storage
                BLOCK_VARIABLES+=("${var_name}=\"\${LOCAL_${var_name}:-\${${i}}}\"  # Secret: prefers local, falls back to Jamf \$$i")

                SECRETS_FILE="$HOME/.jamf_secrets"
                LOCAL_VAR_NAME="LOCAL_${var_name}"

                # Check if secrets file exists AND if the variable is defined in it
                if [[ -f "$SECRETS_FILE" ]] && grep -q "^${LOCAL_VAR_NAME}=" "$SECRETS_FILE"; then
                    echo "   Found existing local secret: $LOCAL_VAR_NAME"
                    BLOCK_LOGGING+=("log \"Config: $param_label [${var_name}]: ******* (Loaded from existing local secret)\"")
                    README_ROWS+=("| $var_name | \$$i | \`${LOCAL_VAR_NAME}\` (Existing) |")
                else
                    echo "   Local secret missing. You will need to add it later."
                    BLOCK_LOGGING+=("log \"Config: $param_label [${var_name}]: ******* (Masked)\"")
                    SECRET_REMINDERS+=("${LOCAL_VAR_NAME}=\"REPLACE_WITH_REAL_SECRET\"")
                    README_ROWS+=("| $var_name | \$$i | \`${LOCAL_VAR_NAME}\` (Secret) |")
                fi
                ;;

            *)
                # Skip - manual configuration
                BLOCK_VARIABLES+=("${var_name}=\"\${${i}}\"  # TODO: Configure secret storage")
                BLOCK_LOGGING+=("log \"Config: $param_label [${var_name}]: ******* (Masked)\"")
                SECRET_REMINDERS+=("${var_name}: Configure secret storage manually")
                README_ROWS+=("| $var_name | \$$i | Manual configuration required |")
                ;;
        esac
    else
        read -rp "Default Local Value: " param_default
        BLOCK_HEADER+=("#   \$$i: $param_label")
        BLOCK_VARIABLES+=("${var_name}=\"\${${i}:-\"${param_default}\"}\"")
        BLOCK_LOGGING+=("log \"Config: $param_label [${var_name}]: \$$var_name\"")

        # Add to README (Visible)
        README_ROWS+=("| $i | $param_label | \`$param_default\` |")
    fi
done

else
    echo "Extension Attributes typically don't use Jamf parameters."
    echo "Skipping parameter collection."
    echo ""
fi

# --- 2.5. Static Configuration Variables (Non-Jamf Parameters) ---
echo ""
if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then
    echo "--- Data Collection Variables ---"
    echo "Extension Attributes often need to query system information."
else
    echo "--- Static Configuration Variables ---"
    echo "These are hardcoded in the script (not MDM parameters)"
fi
read -rp "Add static configuration variables? (y/n): " add_static

declare -a STATIC_VARS
declare -a STATIC_README_ROWS

if [[ "$add_static" =~ ^[Yy] ]]; then
    # Define standard macOS variables library
    declare -A STANDARD_VARS_NAMES=(
        [1]="SERIAL_NUMBER"
        [2]="LOGGED_IN_USER"
        [3]="COMPUTER_NAME"
        [4]="OS_VERSION"
        [5]="MODEL_IDENTIFIER"
        [6]="PRIMARY_IP"
        [7]="HOSTNAME"
        [8]="MAC_ADDRESS"
        [9]="CURRENT_USER_HOME"
        [10]="BOOT_VOLUME"
        [11]="TOTAL_RAM_GB"
        [12]="PROCESSOR_NAME"
    )

    declare -A STANDARD_VARS_COMMANDS=(
        [1]='$(system_profiler SPHardwareDataType | awk '\''/Serial/ {print $4}'\'')'
        [2]='$(stat -f%Su /dev/console)'
        [3]='$(scutil --get ComputerName)'
        [4]='$(sw_vers -productVersion)'
        [5]='$(sysctl -n hw.model)'
        [6]='$(ipconfig getifaddr en0 || ipconfig getifaddr en1)'
        [7]='$(hostname)'
        [8]='$(ifconfig en0 | awk '\''/ether/ {print $2}'\'')'
        [9]='$(eval echo ~$(stat -f%Su /dev/console))'
        [10]='$(diskutil info / | awk '\''/Volume Name/ {print $3}'\'')'
        [11]='$(echo "scale=2; $(sysctl -n hw.memsize) / 1073741824" | bc)'
        [12]='$(sysctl -n machdep.cpu.brand_string)'
    )

    declare -A STANDARD_VARS_DESCRIPTIONS=(
        [1]="Mac serial number"
        [2]="Currently logged in user"
        [3]="Computer name from System Preferences"
        [4]="macOS version number"
        [5]="Hardware model identifier"
        [6]="Primary network IP address"
        [7]="Network hostname"
        [8]="Primary MAC address"
        [9]="Home directory of logged in user"
        [10]="Name of boot volume"
        [11]="Total RAM in gigabytes"
        [12]="CPU processor name"
    )

    echo ""
    echo "Select from standard macOS variables (enter numbers separated by spaces):"
    echo "  1.  SERIAL_NUMBER       - Mac serial number"
    echo "  2.  LOGGED_IN_USER      - Currently logged in user"
    echo "  3.  COMPUTER_NAME       - Computer name from System Preferences"
    echo "  4.  OS_VERSION          - macOS version number"
    echo "  5.  MODEL_IDENTIFIER    - Hardware model identifier"
    echo "  6.  PRIMARY_IP          - Primary network IP address"
    echo "  7.  HOSTNAME            - Network hostname"
    echo "  8.  MAC_ADDRESS         - Primary MAC address"
    echo "  9.  CURRENT_USER_HOME   - Home directory of logged in user"
    echo "  10. BOOT_VOLUME         - Name of boot volume"
    echo "  11. TOTAL_RAM_GB        - Total RAM in gigabytes"
    echo "  12. PROCESSOR_NAME      - CPU processor name"
    echo "  0.  Custom variable"
    echo ""

    read -rp "Selection (e.g., '1 2 4' or '0' for custom, or Enter to skip): " selection

    if [[ -n "$selection" ]]; then
        for num in $selection; do
            if [[ "$num" == "0" ]]; then
                # Custom variable input
                while true; do
                    echo ""
                    read -rp "Custom variable name (or Enter to finish): " static_name
                    [[ -z "$static_name" ]] && break

                    # Convert to uppercase and clean
                    static_name=$(echo "$static_name" | tr '[:lower:]' '[:upper:]' | tr ' ' '_' | sed 's/[^A-Z0-9_]//g')

                    read -rp "Value: " static_value
                    read -rp "Description: " static_desc

                    STATIC_VARS+=("readonly ${static_name}=\"${static_value}\"  # ${static_desc}")
                    STATIC_README_ROWS+=("| ${static_name} | Static | \`${static_value}\` | ${static_desc} |")
                done
            elif [[ "$num" =~ ^[1-9][0-9]*$ ]] && [[ -n "${STANDARD_VARS_NAMES[$num]}" ]]; then
                # Standard variable
                var_name="${STANDARD_VARS_NAMES[$num]}"
                var_cmd="${STANDARD_VARS_COMMANDS[$num]}"
                var_desc="${STANDARD_VARS_DESCRIPTIONS[$num]}"

                STATIC_VARS+=("${var_name}=\"${var_cmd}\"  # ${var_desc}")
                STATIC_README_ROWS+=("| ${var_name} | Runtime | Dynamic | ${var_desc} |")
                echo "  Added: $var_name"
            fi
        done
    fi
fi

# --- 3. Generate Script ---
# Use variables to prevent bump-version.sh from modifying the template
INITIAL_VERSION="1.0.0"
INITIAL_DATE="$(date +%Y-%m-%d)"

if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then
    # Extension Attribute Template
    cat > "$SCRIPT_PATH" << EOF
#!/bin/bash

##################################################################
# SCRIPT:         ${SCRIPT_NAME}.sh
# VERSION:        ${INITIAL_VERSION}
# DESCRIPTION:    Extension Attribute for Jamf Pro inventory reporting
#
# AUTHOR:         $(git config user.name || echo "First Last")
# EMAIL:          $(git config user.email || echo "first.last@example.com")
##################################################################
#
# History
# ${INITIAL_VERSION} - ${INITIAL_DATE} - Initial release
#
##################################################################

# --- Script Metadata ---
readonly SCRIPT_VERSION="${INITIAL_VERSION}"

# --- Static Configuration ---
$(printf '%s\n' "${STATIC_VARS[@]}")

# --- Data Collection Logic ---
# TODO: Add your data collection logic here
# Example with error handling:
# RESULT=\$(command_to_get_data 2>/dev/null)
# RESULT="\${RESULT:-Not Available}"  # Fallback if empty or command fails

# --- Output Result ---
# Extension Attributes MUST output in this format:
RESULT="Not Configured"

echo "<result>\${RESULT}</result>"
exit 0
EOF
else
    # Regular Script Template
    cat > "$SCRIPT_PATH" << EOF
#!/bin/bash

################################################################################
# SCRIPT:      ${SCRIPT_NAME}.sh
# VERSION:     ${INITIAL_VERSION}
# AUTHOR:      $(git config user.name || echo "First Last")
# EMAIL:       $(git config user.email || echo "first.last@example.com")
# DATE:        ${INITIAL_DATE}
# Description: Fancy script that makes something cool happen on a Mac.
#
################################################################################
# PARAMETERS:
$(printf '%s\n' "${BLOCK_HEADER[@]}")
################################################################################
# CHANGELOG
# ${INITIAL_VERSION} - ${INITIAL_DATE} - Initial release
################################################################################

# --- Script Metadata ---
readonly SCRIPT_VERSION="${INITIAL_VERSION}"
readonly SCRIPT_NAME="${SCRIPT_NAME}"

$(if [ "$SECRETS_USED" = true ] && ! printf '%s\n' "${BLOCK_VARIABLES[@]}" | grep -q "op read"; then
    echo '# --- Local Development Secrets ---'
    echo 'if [[ -f "$HOME/.jamf_secrets" ]]; then'
    echo '    source "$HOME/.jamf_secrets"'
    echo 'fi'
elif [ "$SECRETS_USED" = true ]; then
    echo '# --- Local Development Secrets (fallback for non-1Password secrets) ---'
    echo 'if [[ -f "$HOME/.jamf_secrets" ]]; then'
    echo '    source "$HOME/.jamf_secrets"'
    echo 'fi'
fi)

# --- Static Configuration ---
$(printf '%s\n' "${STATIC_VARS[@]}")

# --- Configuration (Jamf Parameters) ---
$(printf '%s\n' "${BLOCK_VARIABLES[@]}")

# --- Logging Setup ---
# shellcheck disable=SC2034
LOG_FILE="/var/log/${SCRIPT_NAME}.log"
exec 2> >(tee -a "\$LOG_FILE" >&2)
function log() { echo "[\$(date '+%Y-%m-%d %H:%M:%S')] INFO: \$*" >&2; }
function log_warn() { echo "[\$(date '+%Y-%m-%d %H:%M:%S')] WARN: \$*" >&2; }
function log_error() { echo "[\$(date '+%Y-%m-%d %H:%M:%S')] ERROR: \$*" >&2; }
function log_success() { echo "[\$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: \$*" >&2; }

# --- Main Logic ---
log "Starting \$SCRIPT_NAME v\$SCRIPT_VERSION..."
$(printf '%s\n' "${BLOCK_LOGGING[@]}")

log "----------------------------------------"
# TODO: Add logic here
log "\$SCRIPT_NAME completed successfully"
exit 0
EOF
fi

chmod +x "$SCRIPT_PATH"

# --- 4. Generate README.md ---
# In new project mode, always generate docs
if [ "$IS_MONOREPO" != true ]; then
    GENERATE_SCAFFOLDING=true
fi

if [ "$GENERATE_SCAFFOLDING" = true ]; then
echo "Generating README..."

if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then
    # EA README
    cat > "$README_PATH" << EOF
# $SCRIPT_NAME

**Type:** Jamf Pro Extension Attribute
**Version:** 1.0.0
**Author:** $(git config user.name || echo "First Last")
**Last Updated:** $(date +%Y-%m-%d)

## Description
This Extension Attribute reports inventory data to Jamf Pro.

## Purpose
Extension Attributes extend Jamf Pro's inventory data with custom information. This script:
- Runs during inventory updates
- Outputs data in \`<result>VALUE</result>\` format
- Should be silent except for the result output
- Typically collects read-only system information

## Static Configuration
$(if [ ${#STATIC_README_ROWS[@]} -gt 0 ]; then
    echo "| Variable | Type | Value | Description |"
    echo "|----------|------|-------|-------------|"
    printf '%s\n' "${STATIC_README_ROWS[@]}"
else
    echo "No static configuration variables defined."
fi)

## Jamf Pro Setup

### 1. Add Extension Attribute
1. Log into Jamf Pro
2. Navigate to **Settings** > **Computer Management** > **Extension Attributes**
3. Click **+ New**
4. Configure:
   - **Display Name:** $SCRIPT_NAME
   - **Description:** [Add description of what this reports]
   - **Data Type:** String (or Integer/Date as appropriate)
   - **Inventory Display:** Choose appropriate category
   - **Input Type:** Script
5. Paste the contents of \`$SCRIPT_NAME.sh\`
6. Click **Save**

### 2. Verify Collection
1. Run \`sudo jamf recon\` on a test Mac
2. Check computer inventory in Jamf Pro
3. Find the new attribute in the configured category

## Local Testing

Test the script locally to verify output format:

\`\`\`bash
./$SCRIPT_NAME.sh

# Expected output format:
# <result>VALUE_HERE</result>
\`\`\`

## Data Type Recommendations

| Data Type | Use When | Example Values |
|-----------|----------|----------------|
| **String** | Text values, version numbers, status | "1.2.3", "Installed", "Active" |
| **Integer** | Numeric counts, IDs, percentages | 42, 0, 100 |
| **Date** | Timestamps, dates | "2025-12-07", "2025-12-07 14:30:00" |

## Versioning
This script uses [Semantic Versioning](https://semver.org/). To bump the version:

\`\`\`bash
./bump-version.sh $SCRIPT_NAME.sh [major|minor|patch] "Description of changes"
\`\`\`
EOF
else
    # Regular README
    cat > "$README_PATH" << EOF
# $SCRIPT_NAME

**Version:** 1.0.0
**Author:** $(git config user.name || echo "First Last")
**Last Updated:** $(date +%Y-%m-%d)

## Description
This script is designed for Jamf Pro deployment.

## Static Configuration
$(if [ ${#STATIC_README_ROWS[@]} -gt 0 ]; then
    echo "| Variable | Type | Value | Description |"
    echo "|----------|------|-------|-------------|"
    printf '%s\n' "${STATIC_README_ROWS[@]}"
else
    echo "No static configuration variables defined."
fi)

## Jamf Parameters
| Parameter | Label | Local Default / Env Var |
|-----------|-------|-------------------------|
$(if [ ${#README_ROWS[@]} -gt 0 ]; then
    printf '%s\n' "${README_ROWS[@]}"
else
    echo "| None | N/A | N/A |"
fi)

## Local Testing

### Prerequisites
$(if [ ${#ONEPASSWORD_SECRETS[@]} -gt 0 ]; then
    echo "This script uses **1Password** for secret management. Ensure you have:"
    echo "1. 1Password CLI installed: \`brew install 1password-cli\`"
    echo "2. Authenticated to 1Password: \`op account list\`"
    echo "3. Secrets stored in 1Password:"
    printf '   - %s\n' "${ONEPASSWORD_SECRETS[@]}"
    echo ""
fi)
$(if grep -q "LOCAL_" <<< "${BLOCK_VARIABLES[*]}" 2>/dev/null; then
    echo "For traditional local secrets, ensure \`~/.jamf_secrets\` exists with required variables."
    echo ""
fi)

### Run the script
\`\`\`bash
sudo ./$SCRIPT_NAME.sh
\`\`\`

### Testing 1Password Integration
$(if [ ${#ONEPASSWORD_SECRETS[@]} -gt 0 ]; then
    echo "Test secret retrieval:"
    echo "\`\`\`bash"
    printf 'op read "%s"\n' "${ONEPASSWORD_SECRETS[0]}"
    echo "\`\`\`"
    echo ""
fi)

## Versioning
This project uses [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes or incompatible API changes
- **MINOR**: New features, backward-compatible
- **PATCH**: Bug fixes, backward-compatible

To bump the version, use the provided version bump script:
\`\`\`bash
# Auto-detect script (typical usage)
./bump-version.sh [major|minor|patch] "Description of changes"

# Or specify script explicitly
./bump-version.sh $SCRIPT_NAME.sh [major|minor|patch] "Description"
\`\`\`
EOF
fi
fi  # end GENERATE_SCAFFOLDING (README)

# --- 5. Generate Version Bump Utility ---
# For new project mode, cd into the project dir (needed for git init later)
if [ "$IS_MONOREPO" != true ]; then
    cd "$PROJECT_DIR" || exit
fi

if [ "$GENERATE_SCAFFOLDING" = true ]; then
echo "Generating bump-version.sh..."

if [ "$IS_MONOREPO" = true ]; then
    BUMP_PATH="$PROJECT_DIR/bump-version.sh"
else
    BUMP_PATH="./bump-version.sh"
fi

cat > "$BUMP_PATH" << 'BUMP_EOF'
#!/bin/bash

################################################################################
# SCRIPT: bump-version.sh
# DESCRIPTION: Semantic version bumping utility for macOS/MDM scripts
#
# USAGE: ./bump-version.sh [SCRIPT_FILE] <major|minor|patch> "Change description"
#
# EXAMPLES:
#   Auto-detect script:
#     ./bump-version.sh patch "Fixed bug in parameter validation"
#
#   Specify script explicitly:
#     ./bump-version.sh my_script.sh minor "Added new feature"
################################################################################

set -euo pipefail

# Parse arguments - support both modes:
# Mode 1: ./bump-version.sh <bump_type> "description"  (auto-detect script)
# Mode 2: ./bump-version.sh <script.sh> <bump_type> "description"  (explicit script)

if [[ $# -eq 3 ]]; then
    # Mode 2: Script explicitly specified
    SCRIPT_FILE="$1"
    BUMP_TYPE="$2"
    CHANGE_DESC="$3"

    if [[ ! -f "$SCRIPT_FILE" ]]; then
        echo "Error: Script file not found: $SCRIPT_FILE"
        exit 1
    fi

    if ! grep -q "^readonly SCRIPT_VERSION=" "$SCRIPT_FILE" 2>/dev/null; then
        echo "Error: $SCRIPT_FILE does not appear to be a versioned script"
        echo "Expected to find 'readonly SCRIPT_VERSION=' line"
        exit 1
    fi

    echo "Target script: $SCRIPT_FILE (explicitly specified)"
    echo ""

elif [[ $# -eq 2 ]]; then
    # Mode 1: Auto-detect script
    BUMP_TYPE="$1"
    CHANGE_DESC="$2"

    # Find the main script (exclude bump-version.sh and any other utility scripts)
    # Strategy: Look for script with SCRIPT_VERSION constant (our generated scripts have this)
    SCRIPT_FILE=""
    shopt -s nullglob
    for file in *.sh; do
        if [[ "$file" != "bump-version.sh" ]] && grep -q "^readonly SCRIPT_VERSION=" "$file" 2>/dev/null; then
            if [[ -n "$SCRIPT_FILE" ]]; then
                echo "Warning: Multiple versioned scripts found:"
                echo "  - $SCRIPT_FILE"
                echo "  - $file"
                echo ""
                echo "Using: $SCRIPT_FILE"
                echo "Tip: Specify the script explicitly: $0 $file $BUMP_TYPE \"$CHANGE_DESC\""
                break
            fi
            SCRIPT_FILE="$file"
        fi
    done

    if [[ -z "$SCRIPT_FILE" ]]; then
        echo "Error: No versioned script found in current directory"
        echo "Expected to find a .sh file with 'readonly SCRIPT_VERSION=' line"
        exit 1
    fi

    echo "Target script: $SCRIPT_FILE (auto-detected)"
    echo ""

else
    echo "Usage: $0 [SCRIPT_FILE] <major|minor|patch> \"Change description\""
    echo ""
    echo "Auto-detect script:"
    echo "  $0 patch \"Fixed bug in parameter validation\""
    echo "  $0 minor \"Added new feature for user notifications\""
    echo "  $0 major \"Breaking change: Removed deprecated parameters\""
    echo ""
    echo "Specify script explicitly:"
    echo "  $0 my_script.sh patch \"Fixed bug\""
    echo "  $0 another_script.sh minor \"Added feature\""
    exit 1
fi

# Extract current version from script
CURRENT_VERSION=$(grep "^readonly SCRIPT_VERSION=" "$SCRIPT_FILE" | sed 's/.*"\(.*\)".*/\1/')
if [[ -z "$CURRENT_VERSION" ]]; then
    echo "Error: Could not find SCRIPT_VERSION in $SCRIPT_FILE"
    exit 1
fi

echo "Current version: $CURRENT_VERSION"

# Parse version components
IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"

# Bump version based on type
case "$BUMP_TYPE" in
    major)
        major=$((major + 1))
        minor=0
        patch=0
        ;;
    minor)
        minor=$((minor + 1))
        patch=0
        ;;
    patch)
        patch=$((patch + 1))
        ;;
    *)
        echo "Error: Invalid bump type. Use major, minor, or patch"
        exit 1
        ;;
esac

NEW_VERSION="${major}.${minor}.${patch}"
TODAY=$(date +%Y-%m-%d)

echo "New version: $NEW_VERSION"
echo "Change: $CHANGE_DESC"

# Update version in script file header (only lines with actual version numbers, not variables)
# Match VERSION: followed by any amount of whitespace and a version number, preserving alignment
sed -i.bak "s/^# VERSION:[[:space:]]*[0-9][0-9.]*$/# VERSION:     $NEW_VERSION/" "$SCRIPT_FILE"

# Update SCRIPT_VERSION constant (only lines with actual version numbers, not variables)
sed -i.bak "s/^readonly SCRIPT_VERSION=\"[0-9][0-9.]*\"$/readonly SCRIPT_VERSION=\"$NEW_VERSION\"/" "$SCRIPT_FILE"

# Update CHANGELOG in script header (add new entry at top - only first occurrence)
CHANGELOG_LINE="# $NEW_VERSION - $TODAY - $CHANGE_DESC"
sed -i.bak "0,/^# CHANGELOG$/s//# CHANGELOG\n$CHANGELOG_LINE/" "$SCRIPT_FILE"

# Update README.md version
sed -i.bak "s/^\*\*Version:\*\* .*$/\*\*Version:\*\* $NEW_VERSION/" README.md
sed -i.bak "s/^\*\*Last Updated:\*\* .*$/\*\*Last Updated:\*\* $TODAY/" README.md

# Update CHANGELOG.md (insert new version section before first existing version entry)
if [[ -f "CHANGELOG.md" ]]; then
    # Build the new entry block
    NEW_ENTRY="## [$NEW_VERSION] - $TODAY\n"
    case "$BUMP_TYPE" in
        major) NEW_ENTRY+="\n### Changed\n- $CHANGE_DESC\n" ;;
        minor) NEW_ENTRY+="\n### Added\n- $CHANGE_DESC\n" ;;
        patch) NEW_ENTRY+="\n### Fixed\n- $CHANGE_DESC\n" ;;
    esac

    # Insert before the first '## [' version heading
    if grep -q "^## \[" CHANGELOG.md; then
        sed -i.bak "0,/^## \[/{s/^## \[/${NEW_ENTRY}\n## [/}" CHANGELOG.md
    else
        # No existing version entries — append to end
        printf '\n%b\n' "$NEW_ENTRY" >> CHANGELOG.md
    fi
fi

# Update munkipkg build-info if present (supports both JSON and plist formats)
# Check common locations: root, pkg/, and build/ directories
for build_info_path in build-info.json pkg/build-info.json build/build-info.json build-info.plist pkg/build-info.plist build/build-info.plist; do
    if [[ -f "$build_info_path" ]]; then
        echo "Updating munkipkg version in: $build_info_path"
        if [[ "$build_info_path" == *.json ]]; then
            # Update JSON format
            sed -i.bak "s/\"version\": \"[^\"]*\"/\"version\": \"$NEW_VERSION\"/" "$build_info_path"
            rm -f "${build_info_path}.bak" 2>/dev/null || true
        elif [[ "$build_info_path" == *.plist ]]; then
            # Update plist format using PlistBuddy
            /usr/libexec/PlistBuddy -c "Set :version $NEW_VERSION" "$build_info_path" 2>/dev/null || true
        fi
    fi
done

# Clean up backup files
rm -f "$SCRIPT_FILE.bak" README.md.bak CHANGELOG.md.bak 2>/dev/null || true

echo ""
echo "SUCCESS: Version bumped to $NEW_VERSION"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Commit changes: git add . && git commit -m \"chore: bump version to $NEW_VERSION\""
echo "  3. Tag release: git tag -a \"v$NEW_VERSION\" -m \"$CHANGE_DESC\""
echo "  4. Push changes: git push && git push --tags"
BUMP_EOF

chmod +x "$BUMP_PATH"

echo "Generating CHANGELOG.md..."
cat > "$CHANGELOG_PATH" << EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - $(date +%Y-%m-%d)

### Added
- Initial release of $SCRIPT_NAME
$(if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then
    echo "- Extension Attribute for Jamf Pro inventory reporting"
    echo "- Data collection logic"
    echo "- Proper <result> output formatting"
else
    echo "- Core functionality implemented"
    echo "- Jamf Pro parameter support"
    [ "$SECRETS_USED" = true ] && echo "- Secure secrets management"
fi)
EOF
fi  # end GENERATE_SCAFFOLDING (CHANGELOG)

# --- 6. Branching Git Logic ---

if [ "$IS_MONOREPO" = true ]; then
    # --- EXISTING REPO FLOW ---

    # Prompt for Branching
    echo "You are in an existing Git repository."
    read -rp "Do you want to create a new branch for this script? (Recommended) (y/n): " do_branch

    if [[ "$do_branch" =~ ^[Yy] ]]; then
        # Detect default branch (main or master)
        DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | sed -n '/HEAD branch/s/.*: //p')

        if [[ -z "$DEFAULT_BRANCH" ]]; then
            # Fallback if offline or no remote
            DEFAULT_BRANCH="main"
        fi

        echo "Switching to $DEFAULT_BRANCH and updating..."
        git checkout "$DEFAULT_BRANCH" 2>/dev/null || git checkout master 2>/dev/null || true
        git pull -q 2>/dev/null || true

        # Create new branch
        BRANCH_NAME="feature/$SCRIPT_NAME"
        echo "Creating branch: $BRANCH_NAME"

        # Check if branch exists
        if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
            echo "Warning: Branch $BRANCH_NAME already exists. Switching to it."
            git checkout "$BRANCH_NAME"
        else
            git checkout -b "$BRANCH_NAME"
        fi
    fi

    # 3. Add the files
    echo "Staging files..."
    if [ "$GENERATE_SCAFFOLDING" = true ]; then
        git add "$SCRIPT_PATH" "$README_PATH" "$CHANGELOG_PATH" "$BUMP_PATH"
    else
        git add "$SCRIPT_PATH"
    fi

    echo "Files staged on branch: $(git branch --show-current)"
    echo "   Next Step: git commit -m 'Add $SCRIPT_NAME script'"

else
    # --- NEW REPO FLOW ---

    echo "Initializing Git..."
    git init -q

    echo "Generating macOS .gitignore..."
    cat > .gitignore << EOF
# --- macOS System Files ---
.DS_Store
.AppleDouble
.LSOverride
._*
.DocumentRevisions-V100
.fseventsd
.Spotlight-V100
.TemporaryItems
.Trashes
.VolumeIcon.icns
.com.apple.timemachine.donotpresent

# --- Editors & IDEs ---
.vscode/
.idea/
*.swp

# --- Secrets & Local Configs (Safety Net) ---
.env
.env.local
.jamf_secrets
secrets.sh
config.local

# --- Binary Artifacts (Don't commit these!) ---
*.dmg
*.zip
*.tar.gz

# --- munkipkg Build Artifacts ---
# Allow pkg/ source directory but ignore built packages
pkg/build/
**/build/*.pkg
*.pkg
*.pkg.zip
EOF

# Install Pre-commit if available
if command -v pre-commit &> /dev/null; then
    echo ""
    echo "Pre-commit hooks protect against secrets and code quality issues."
    read -rp "Choose hook level - (b)asic [secrets only] or (e)nhanced [9 checks]? (b/e): " hook_level

    if [[ "$hook_level" =~ ^[Ee] ]]; then
        # Enhanced: 9 hooks (secrets, linting, quality checks)
        cat > .pre-commit-config.yaml << 'EOF'
repos:
  # Secret scanning with gitleaks
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
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
        args: ['--maxkb=1000']
      - id: check-merge-conflict
      - id: detect-private-key
EOF
        echo "Installing enhanced pre-commit hooks (9 checks)..."
    else
        # Basic: Just gitleaks for secret scanning
        cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
EOF
        echo "Installing basic pre-commit hooks (secrets only)..."
    fi

    pre-commit install
    git add .pre-commit-config.yaml
    echo "✓ Pre-commit hooks installed"
else
    echo "   (Skipping pre-commit setup - 'pre-commit' not installed)"
    echo "   To enable: brew install pre-commit"
fi

# Optional: Generate GitHub Actions workflow for version validation
read -rp "Add GitHub Actions workflow for version validation? (y/n): " add_workflow
if [[ "$add_workflow" =~ ^[Yy] ]]; then
    echo "Generating GitHub Actions workflow..."
    mkdir -p .github/workflows
    cat > .github/workflows/validate-version.yml << 'WORKFLOW_EOF'
name: Validate Version

on:
  pull_request:
    branches: [ main, master ]
  push:
    tags:
      - 'v*'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Extract version from script
        id: script_version
        run: |
          # Find versioned script (same logic as bump-version.sh)
          SCRIPT_FILE=""
          shopt -s nullglob
          for file in *.sh; do
            if [[ "\$file" != "bump-version.sh" ]] && grep -q "^readonly SCRIPT_VERSION=" "\$file" 2>/dev/null; then
              SCRIPT_FILE="\$file"
              break
            fi
          done

          if [[ -z "\$SCRIPT_FILE" ]]; then
            echo "Error: No versioned script found"
            exit 1
          fi

          echo "Found script: \$SCRIPT_FILE"
          VERSION=\$(grep "^readonly SCRIPT_VERSION=" "\$SCRIPT_FILE" | sed 's/.*"\\(.*\\)".*/\\1/')
          echo "version=\$VERSION" >> \$GITHUB_OUTPUT
          echo "Script version: \$VERSION"

      - name: Extract version from README
        id: readme_version
        run: |
          VERSION=$(grep "^\*\*Version:\*\*" README.md | sed 's/.*: \(.*\)$/\1/')
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "README version: $VERSION"

      - name: Validate versions match
        run: |
          if [ "${{ steps.script_version.outputs.version }}" != "${{ steps.readme_version.outputs.version }}" ]; then
            echo "ERROR: Version mismatch!"
            echo "Script: ${{ steps.script_version.outputs.version }}"
            echo "README: ${{ steps.readme_version.outputs.version }}"
            exit 1
          fi
          echo "SUCCESS: Versions match: ${{ steps.script_version.outputs.version }}"

      - name: Validate tag matches version (on tag push)
        if: startsWith(github.ref, 'refs/tags/')
        run: |
          TAG_VERSION=${GITHUB_REF#refs/tags/v}
          SCRIPT_VERSION="${{ steps.script_version.outputs.version }}"
          if [ "$TAG_VERSION" != "$SCRIPT_VERSION" ]; then
            echo "ERROR: Tag version ($TAG_VERSION) does not match script version ($SCRIPT_VERSION)"
            exit 1
          fi
          echo "SUCCESS: Tag matches version: v$SCRIPT_VERSION"

  shellcheck:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run ShellCheck
        uses: ludeeus/action-shellcheck@master
        with:
          ignore_paths: .github
WORKFLOW_EOF
    git add .github/workflows/validate-version.yml
fi

    git add .
    git commit -m "Initial commit: Scaffolding for $SCRIPT_NAME"

    # GitHub Remote Creation
    if command -v gh &> /dev/null; then
        read -rp "Create private GitHub repo? (y/n): " create_gh
        if [[ "$create_gh" =~ ^[Yy] ]]; then
            echo "Creating GitHub repository..."
            gh repo create "$SCRIPT_NAME" --private --source=. --remote=origin --push
            echo "Live at: $(gh repo view --json url -q .url)"
        fi
    fi
fi

# --- 7. Final Summary ---
echo ""
echo "=============================================="
if [ "$IS_MONOREPO" = true ]; then
    echo "       Script Successfully Created!          "
    echo "=============================================="
    echo "Mode: Monorepo (existing repo)"
    echo "Branch: $(git branch --show-current 2>/dev/null || echo 'N/A')"
else
    echo "      Project Successfully Created!          "
    echo "=============================================="
    echo "Mode: New Project (isolated repo)"
    echo "Location: $PROJECT_DIR"
fi
echo "Template: $(if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then echo "Extension Attribute"; else echo "Regular Script"; fi)"
echo ""
echo "Generated Files:"
echo "  * ${SCRIPT_NAME}.sh (v1.0.0)"
if [ "$IS_MONOREPO" = true ]; then
    if [ "$GENERATE_SCAFFOLDING" = true ]; then
        echo "  * ${SCRIPT_NAME}_README.md"
        echo "  * ${SCRIPT_NAME}_CHANGELOG.md"
        echo "  * bump-version.sh"
    fi
else
    echo "  * README.md"
    echo "  * CHANGELOG.md"
    echo "  * .gitignore"
    echo "  * bump-version.sh"
    [[ -f ".github/workflows/validate-version.yml" ]] && echo "  * .github/workflows/validate-version.yml"
fi
echo ""

if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then
    echo "Extension Attribute Setup:"
    echo "  1. Test locally: ./${SCRIPT_NAME}.sh"
    echo "  2. Verify output format: <result>VALUE</result>"
    echo "  3. Add to Jamf Pro: Settings > Extension Attributes"
    echo "  4. Run inventory: sudo jamf recon"
    echo ""
fi

if [ "$SECRETS_USED" = true ] && [ ${#SECRET_REMINDERS[@]} -gt 0 ]; then
    echo "⚠️  SECRETS CONFIGURATION NEEDED:"

    # Check if any 1Password secrets
    if [ ${#ONEPASSWORD_SECRETS[@]} -gt 0 ]; then
        echo ""
        echo "1Password Secrets (ensure these exist):"
        printf '   %s\n' "${ONEPASSWORD_SECRETS[@]}"
        echo ""
        echo "   Access secrets with: op read 'op://Vault/Item/field'"
    fi

    # Check if any traditional secrets or manual configs
    has_traditional=false
    for reminder in "${SECRET_REMINDERS[@]}"; do
        if [[ "$reminder" != 1Password:* ]]; then
            has_traditional=true
            break
        fi
    done

    if [ "$has_traditional" = true ]; then
        echo ""
        echo "Add these to ~/.jamf_secrets:"
        for reminder in "${SECRET_REMINDERS[@]}"; do
            if [[ "$reminder" != 1Password:* ]]; then
                echo "   $reminder"
            fi
        done
    fi

    # Show any 1Password reminders (for items not created during generation)
    for reminder in "${SECRET_REMINDERS[@]}"; do
        if [[ "$reminder" == 1Password:* ]]; then
            echo ""
            echo "   $reminder"
        fi
    done

    echo ""
fi

echo "Quick Start:"
echo "  1. Edit your script: ${SCRIPT_NAME}.sh"
if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then
    echo "  2. Test output: ./${SCRIPT_NAME}.sh"
    echo "  3. Add to Jamf Pro Extension Attributes"
else
    echo "  2. Test locally: sudo ./${SCRIPT_NAME}.sh"
fi
if [ "$IS_MONOREPO" = true ]; then
    echo "  $(if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then echo "4"; else echo "3"; fi). Bump version: ./bump-version.sh ${SCRIPT_NAME}.sh patch \"Your changes\""
    echo "  $(if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then echo "5"; else echo "4"; fi). Commit: git commit -m \"Add ${SCRIPT_NAME} script\""
else
    echo "  $(if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then echo "4"; else echo "3"; fi). Bump version: ./bump-version.sh patch \"Your changes\""
    echo "  $(if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then echo "5"; else echo "4"; fi). Commit & tag: git commit -am \"your message\" && git tag v1.0.1"
fi
echo ""

# Open VS Code
if command -v code &> /dev/null; then
    code "$PROJECT_DIR"
fi
