#!/bin/bash

################################################################################
# SCRIPT:      shikomi.sh
# VERSION:     2.1.2
# AUTHOR:      Matt Parker
# DATE:        2025-12-07
# DESCRIPTION: Smart macOS/MDM Script Generator
#              - Detects if you are in an existing Git Repo (Monorepo mode)
#              - If not, creates a new Repo/Project (Micro-repo mode)
#              - Generates versioned scripts with semantic versioning
#              - Initializes Git + Pre-Commit Hooks + GitHub integration
################################################################################
# CHANGELOG
# 2.1.2 - 2026-06-19 - Clarified shellcheck disable comments to instruct developers to remove them once the variable is used
# 2.1.1 - 2026-06-19 - Add SC2034 suppression for scaffolded variables and end-of-wizard note
# 2.1.0 - 2026-03-27 - Removed per-repo bump-version.sh scaffolding; bump-version is now used exclusively as a system-installed command via install.sh
# 2.0.0 - 2026-03-23 - Non-interactive CLI mode (--auto + flags), Claude Code scaffolding (--claude), plutil-based --params-file
# 1.9.0 - 2026-03-22 - Extracted monolithic script into modular lib/ structure (6 sourced library files)
# 1.8.0 - 2026-03-22 - Added Jamf Pro deploy workflow, --commit flag, portable bump-version, monorepo path resolution, removed bundled workflows
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
readonly SCRIPT_VERSION="2.1.2"
readonly GENERATOR_NAME="shikomi"
SHIKOMI_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Resolve and source lib/ ---
if [[ -d "$SHIKOMI_DIR/lib" ]]; then
    SHIKOMI_LIB="$SHIKOMI_DIR/lib"
elif [[ -d "$HOME/.local/lib/shikomi/lib" ]]; then
    SHIKOMI_LIB="$HOME/.local/lib/shikomi/lib"
elif [[ -d "/usr/local/lib/shikomi/lib" ]]; then
    SHIKOMI_LIB="/usr/local/lib/shikomi/lib"
else
    echo "Error: Cannot find shikomi lib/ directory"
    echo "If you recently updated, run: ./install.sh --update (from the shikomi repo)"
    exit 1
fi

source "$SHIKOMI_LIB/templates.sh"
source "$SHIKOMI_LIB/readme.sh"
source "$SHIKOMI_LIB/docs.sh"
source "$SHIKOMI_LIB/workflows.sh"
source "$SHIKOMI_LIB/git-setup.sh"
source "$SHIKOMI_LIB/collection.sh"
source "$SHIKOMI_LIB/claude-setup.sh"

# --- 0. Argument Parsing ---

show_usage() {
    echo "Shikomi v$SCRIPT_VERSION - Smart macOS/MDM Script Generator"
    echo ""
    echo "Usage: $(basename "$0") <script_name> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --version                Show version"
    echo "  -h, --help                   Show this help"
    echo ""
    echo "Non-interactive mode:"
    echo "  --auto                       Skip all prompts, use defaults for unset flags"
    echo "  --template <regular|ea>      Script template type (default: regular)"
    echo "  --ea-suffix <y|n>            Add _ea suffix for EA scripts (default: y)"
    echo "  --scaffolding <y|n>          Generate per-script README/CHANGELOG (monorepo only)"
    echo "  --params-file <path>         Load parameters from JSON file (see docs for schema)"
    echo "  --no-params                  Skip parameter collection entirely"
    echo "  --static-vars <1,2,4|none>   Standard macOS variables by number (comma-separated)"
    echo "  --branch <y|n>              Create feature branch in monorepo (default: y)"
    echo "  --hooks <basic|enhanced|none> Pre-commit hook level (default: basic)"
    echo "  --workflow <y|n>             Add GitHub Actions validation workflow"
    echo "  --deploy-workflow <y|n>      Add Jamf Pro deploy workflow"
    echo "  --github <y|n>               Create private GitHub repo"
    echo "  --claude <y|n>               Generate CLAUDE.md and SESSION_DIARY.md"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") my_script                          # Interactive wizard"
    echo "  $(basename "$0") my_script --auto                   # Fully automated, defaults"
    echo "  $(basename "$0") my_script --auto --claude y        # Automated + Claude Code setup"
    echo "  $(basename "$0") check_disk --auto --template ea --static-vars \"1,4,11\""
    echo "  $(basename "$0") deploy_agent --auto --params-file params.json --workflow y"
}

# Pre-scan for --version / --help before requiring SCRIPT_NAME
case "${1:-}" in
    --version|-v) echo "Shikomi v$SCRIPT_VERSION"; exit 0 ;;
    --help|-h)    show_usage; exit 0 ;;
esac

SCRIPT_NAME="${1:-}"
if [[ -z "$SCRIPT_NAME" ]]; then
    echo "Usage: $(basename "$0") <script_name> [OPTIONS]"
    echo "Run '$(basename "$0") --help' for full usage"
    exit 1
fi
shift  # consume SCRIPT_NAME, remaining args are flags

# --- Flag defaults (empty = not set, use interactive or --auto default) ---
FLAG_AUTO=false
FLAG_TEMPLATE=""
FLAG_EA_SUFFIX=""
FLAG_SCAFFOLDING=""
FLAG_PARAMS_FILE=""
FLAG_NO_PARAMS=false
FLAG_STATIC_VARS=""
FLAG_BRANCH=""
FLAG_HOOKS=""
FLAG_WORKFLOW=""
FLAG_DEPLOY_WORKFLOW=""
FLAG_GITHUB=""
FLAG_CLAUDE=""

# --- Parse flags ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --non-interactive|--auto)
            FLAG_AUTO=true
            shift ;;
        --template)
            FLAG_TEMPLATE="$2"; shift 2 ;;
        --ea-suffix)
            FLAG_EA_SUFFIX="$2"; shift 2 ;;
        --scaffolding)
            FLAG_SCAFFOLDING="$2"; shift 2 ;;
        --params-file)
            FLAG_PARAMS_FILE="$2"; shift 2 ;;
        --no-params)
            FLAG_NO_PARAMS=true; shift ;;
        --static-vars)
            FLAG_STATIC_VARS="$2"; shift 2 ;;
        --branch)
            FLAG_BRANCH="$2"; shift 2 ;;
        --hooks)
            FLAG_HOOKS="$2"; shift 2 ;;
        --workflow)
            FLAG_WORKFLOW="$2"; shift 2 ;;
        --deploy-workflow)
            FLAG_DEPLOY_WORKFLOW="$2"; shift 2 ;;
        --github)
            FLAG_GITHUB="$2"; shift 2 ;;
        --claude)
            FLAG_CLAUDE="$2"; shift 2 ;;
        --no-claude)
            FLAG_CLAUDE="n"; shift ;;
        *)
            echo "Error: Unknown option: $1"
            echo "Run '$(basename "$0") --help' for usage"
            exit 1 ;;
    esac
done

# --- 1. Prerequisites Check ---
if ! command -v gh &> /dev/null; then
    echo "Warning: GitHub CLI ('gh') not installed. Remote repo creation will be skipped."
fi
if ! command -v pre-commit &> /dev/null; then
    echo "Warning: 'pre-commit' not installed. Security hooks will be skipped."
fi

# --- 2. Context Awareness: Detect Existing Git Repo ---
if [[ -z "$SCRIPT_NAME" ]]; then
    echo "Usage: $(basename "$0") <script_name> [OPTIONS]"
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

    # In monorepo mode, per-script scaffolding (README, CHANGELOG) is optional
    GENERATE_SCAFFOLDING=false
    if [[ -n "$FLAG_SCAFFOLDING" ]]; then
        [[ "$FLAG_SCAFFOLDING" =~ ^[Yy] ]] && GENERATE_SCAFFOLDING=true
    elif [[ "$FLAG_AUTO" == true ]]; then
        GENERATE_SCAFFOLDING=false
    else
        read -rp "Generate per-script README and CHANGELOG? (y/n) [n]: " gen_scaffolding
        if [[ "$gen_scaffolding" =~ ^[Yy] ]]; then
            GENERATE_SCAFFOLDING=true
        fi
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
if [[ -n "$FLAG_TEMPLATE" ]]; then
    case "$FLAG_TEMPLATE" in
        regular) template_choice="1" ;;
        ea)      template_choice="2" ;;
        *)
            echo "Error: --template must be 'regular' or 'ea'"
            exit 1 ;;
    esac
elif [[ "$FLAG_AUTO" == true ]]; then
    template_choice="1"
else
    echo ""
    echo "--- Script Template Selection ---"
    echo "What type of script do you want to create?"
    echo "  1) Regular Script     - Full-featured automation with parameters, logging, secrets"
    echo "  2) Extension Attribute - Simple Jamf inventory reporting (<result> output)"
    read -rp "Selection (1/2) [1]: " template_choice
    template_choice="${template_choice:-1}"
fi

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
            if [[ -n "$FLAG_EA_SUFFIX" ]]; then
                add_suffix="$FLAG_EA_SUFFIX"
            elif [[ "$FLAG_AUTO" == true ]]; then
                add_suffix="y"
            else
                read -rp "Add '_ea' suffix to script name? (y/n) [y]: " add_suffix
                add_suffix="${add_suffix:-y}"
            fi
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

# --- 3. Interactive Wizard: Parameter Collection ---
declare -a BLOCK_HEADER
declare -a BLOCK_VARIABLES
declare -a BLOCK_LOGGING
declare -a README_ROWS
SECRETS_USED=false
declare -a SECRET_REMINDERS
declare -a ONEPASSWORD_SECRETS  # Track 1Password secret references

# Only collect Jamf parameters for regular scripts
if [[ "$SCRIPT_TEMPLATE" == "regular" ]]; then
    if [[ -n "$FLAG_PARAMS_FILE" ]]; then
        # Non-interactive: load parameters from JSON file
        echo "Loading parameters from: $FLAG_PARAMS_FILE"
        parse_params_file "$FLAG_PARAMS_FILE"
    elif [[ "$FLAG_NO_PARAMS" == true ]] || [[ "$FLAG_AUTO" == true && -z "$FLAG_PARAMS_FILE" ]]; then
        echo "Skipping parameter collection."
    else
        # Interactive parameter collection
        echo "Define Parameters (\$4-\$11). Press [Enter] on Label to finish."
        echo ""

for i in {4..11}; do
    echo "--- Parameter $i ---"
    read -rp "Label (e.g. 'Target Dept'): " param_label
    [[ -z "$param_label" ]] && break

    var_name=$(echo "$param_label" | tr '[:lower:]' '[:upper:]' | tr ' ' '_' | sed 's/[^A-Z0-9_]//g')

    read -rp "Is this a secret? (y/n): " is_secret

    if [[ "$is_secret" =~ ^[Yy] ]]; then
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

                apply_secret_parameter_1password "$i" "$param_label" "$var_name" "$op_vault" "$op_item" "$op_field"
                ;;

            2)
                apply_secret_parameter_local "$i" "$param_label" "$var_name"
                ;;

            *)
                apply_secret_parameter_manual "$i" "$param_label" "$var_name"
                ;;
        esac
    else
        read -rp "Default Local Value: " param_default
        apply_jamf_parameter "$i" "$param_label" "$var_name" "$param_default"
    fi
done
    fi  # end interactive vs non-interactive params

else
    echo "Extension Attributes typically don't use Jamf parameters."
    echo "Skipping parameter collection."
    echo ""
fi

# --- 3.5. Static Configuration Variables (Non-Jamf Parameters) ---
declare -a STATIC_VARS
declare -a STATIC_README_ROWS

if [[ -n "$FLAG_STATIC_VARS" ]]; then
    # Non-interactive: use flag value
    if [[ "$FLAG_STATIC_VARS" != "none" ]]; then
        get_standard_vars_library
        IFS=',' read -ra _var_nums <<< "$FLAG_STATIC_VARS"
        for num in "${_var_nums[@]}"; do
            if [[ -n "${STANDARD_VARS_NAMES[$num]:-}" ]]; then
                apply_standard_var "$num"
            else
                echo "Warning: Unknown standard variable number: $num (skipping)"
            fi
        done
    fi
elif [[ "$FLAG_AUTO" == true ]]; then
    : # skip static vars in auto mode
else
    echo ""
    if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then
        echo "--- Data Collection Variables ---"
        echo "Extension Attributes often need to query system information."
    else
        echo "--- Static Configuration Variables ---"
        echo "These are hardcoded in the script (not MDM parameters)"
    fi
    read -rp "Add static configuration variables? (y/n): " add_static

    if [[ "$add_static" =~ ^[Yy] ]]; then
        get_standard_vars_library

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

                        apply_custom_var "$static_name" "$static_value" "$static_desc"
                    done
                elif [[ "$num" =~ ^[1-9][0-9]*$ ]] && [[ -n "${STANDARD_VARS_NAMES[$num]}" ]]; then
                    apply_standard_var "$num"
                fi
            done
        fi
    fi
fi

# --- 4. Generate Script ---
# Use variables to prevent bump-version.sh from modifying the template
INITIAL_VERSION="1.0.0"
INITIAL_DATE="$(date +%Y-%m-%d)"

if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then
    generate_ea_script
else
    generate_regular_script
fi

# --- 5. Generate Documentation ---
# In new project mode, always generate docs
if [ "$IS_MONOREPO" != true ]; then
    GENERATE_SCAFFOLDING=true
fi

if [ "$GENERATE_SCAFFOLDING" = true ]; then
    echo "Generating README..."
    if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then
        generate_ea_readme
    else
        generate_regular_readme
    fi

    echo "Generating CHANGELOG.md..."
    generate_changelog
fi  # end GENERATE_SCAFFOLDING

# --- 5.5. Claude Code Configuration ---
GENERATE_CLAUDE=false
if [[ -n "$FLAG_CLAUDE" ]]; then
    [[ "$FLAG_CLAUDE" =~ ^[Yy] ]] && GENERATE_CLAUDE=true
elif [[ "$FLAG_AUTO" == true ]]; then
    GENERATE_CLAUDE=false  # opt-in feature
else
    read -rp "Set up Claude Code configuration? (CLAUDE.md + SESSION_DIARY.md) (y/n) [n]: " setup_claude
    if [[ "$setup_claude" =~ ^[Yy] ]]; then
        GENERATE_CLAUDE=true
    fi
fi

if [[ "$GENERATE_CLAUDE" == true ]]; then
    if [[ "$IS_MONOREPO" == true ]]; then
        # In monorepo mode, generate at repo root only if files don't exist
        if [[ -f "$REPO_ROOT/CLAUDE.md" ]]; then
            echo "CLAUDE.md already exists at repo root, skipping."
        else
            _SAVED_PROJECT_DIR="$PROJECT_DIR"
            PROJECT_DIR="$REPO_ROOT"
            echo "Generating CLAUDE.md..."
            generate_claude_md
            PROJECT_DIR="$_SAVED_PROJECT_DIR"
        fi
        if [[ -f "$REPO_ROOT/SESSION_DIARY.md" ]]; then
            echo "SESSION_DIARY.md already exists at repo root, skipping."
        else
            _SAVED_PROJECT_DIR="$PROJECT_DIR"
            PROJECT_DIR="$REPO_ROOT"
            echo "Generating SESSION_DIARY.md..."
            init_session_diary
            PROJECT_DIR="$_SAVED_PROJECT_DIR"
        fi
    else
        echo "Generating Claude Code configuration..."
        generate_claude_md
        init_session_diary
    fi
fi

# --- 6. Branching Git Logic ---

if [ "$IS_MONOREPO" = true ]; then
    # --- EXISTING REPO FLOW ---

    # Prompt for Branching
    if [[ -n "$FLAG_BRANCH" ]]; then
        do_branch="$FLAG_BRANCH"
    elif [[ "$FLAG_AUTO" == true ]]; then
        do_branch="y"
    else
        echo "You are in an existing Git repository."
        read -rp "Do you want to create a new branch for this script? (Recommended) (y/n): " do_branch
    fi

    if [[ "$do_branch" =~ ^[Yy] ]]; then
        create_feature_branch
    fi

    # Optional: Generate GitHub Actions workflows (monorepo versions)
    if [[ ! -f "$REPO_ROOT/.github/workflows/validate-scripts.yml" ]]; then
        if [[ -n "$FLAG_WORKFLOW" ]]; then
            add_workflow="$FLAG_WORKFLOW"
        elif [[ "$FLAG_AUTO" == true ]]; then
            add_workflow="n"
        else
            read -rp "Add GitHub Actions workflow for PR validation? (y/n): " add_workflow
        fi
        if [[ "$add_workflow" =~ ^[Yy] ]]; then
            echo "Generating monorepo validation workflow..."
            generate_monorepo_validate_workflow "$REPO_ROOT"
        fi
    fi

    if [[ ! -f "$REPO_ROOT/.github/workflows/deploy-to-jamf.yml" ]]; then
        if [[ -n "$FLAG_DEPLOY_WORKFLOW" ]]; then
            add_deploy_workflow="$FLAG_DEPLOY_WORKFLOW"
        elif [[ "$FLAG_AUTO" == true ]]; then
            add_deploy_workflow="n"
        else
            read -rp "Add workflow to deploy scripts to Jamf Pro on merge? (y/n): " add_deploy_workflow
        fi
        if [[ "$add_deploy_workflow" =~ ^[Yy] ]]; then
            echo "Generating monorepo deploy workflow..."
            generate_monorepo_deploy_workflow "$REPO_ROOT"
        fi
    fi

    stage_monorepo_files

else
    # --- NEW REPO FLOW ---

    # For new project mode, cd into the project dir (needed for git init)
    cd "$PROJECT_DIR" || exit

    init_new_repo

    echo "Generating macOS .gitignore..."
    generate_gitignore

    # Install Pre-commit if available
    if [[ "$FLAG_HOOKS" == "none" ]]; then
        echo "Skipping pre-commit hooks (--hooks none)."
    elif install_precommit_hooks; then
        if [[ -n "$FLAG_HOOKS" ]]; then
            hook_level="$FLAG_HOOKS"
        elif [[ "$FLAG_AUTO" == true ]]; then
            hook_level="basic"
        else
            echo ""
            echo "Pre-commit hooks protect against secrets and code quality issues."
            read -rp "Choose hook level - (b)asic [secrets only] or (e)nhanced [9 checks]? (b/e): " hook_level
        fi

        if [[ "$hook_level" =~ ^[Ee] ]] || [[ "$hook_level" == "enhanced" ]]; then
            generate_precommit_config "enhanced"
        else
            generate_precommit_config "basic"
        fi
    fi

    # Optional: Generate GitHub Actions workflows
    if [[ -n "$FLAG_WORKFLOW" ]]; then
        add_workflow="$FLAG_WORKFLOW"
    elif [[ "$FLAG_AUTO" == true ]]; then
        add_workflow="n"
    else
        read -rp "Add GitHub Actions workflow for PR validation (ShellCheck + version checks)? (y/n): " add_workflow
    fi
    if [[ "$add_workflow" =~ ^[Yy] ]]; then
        echo "Generating validation workflow..."
        generate_validate_workflow "."

        # Optional: Add Jamf Pro deployment workflow
        if [[ -n "$FLAG_DEPLOY_WORKFLOW" ]]; then
            add_deploy_workflow="$FLAG_DEPLOY_WORKFLOW"
        elif [[ "$FLAG_AUTO" == true ]]; then
            add_deploy_workflow="n"
        else
            read -rp "Also add a workflow to deploy scripts to Jamf Pro on merge? (y/n): " add_deploy_workflow
        fi
        if [[ "$add_deploy_workflow" =~ ^[Yy] ]]; then
            echo "Generating Jamf Pro deploy workflow..."
            generate_deploy_workflow "."
        fi
    fi

    stage_and_commit_new_repo

    # GitHub Remote Creation
    if command -v gh &> /dev/null; then
        if [[ -n "$FLAG_GITHUB" ]]; then
            create_gh="$FLAG_GITHUB"
        elif [[ "$FLAG_AUTO" == true ]]; then
            create_gh="n"
        else
            read -rp "Create private GitHub repo? (y/n): " create_gh
        fi
        if [[ "$create_gh" =~ ^[Yy] ]]; then
            create_github_repo
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
    fi
else
    echo "  * README.md"
    echo "  * CHANGELOG.md"
    echo "  * .gitignore"
    [[ -f ".github/workflows/validate-version.yml" ]] && echo "  * .github/workflows/validate-version.yml"
    [[ -f ".github/workflows/deploy-to-jamf.yml" ]] && echo "  * .github/workflows/deploy-to-jamf.yml"
fi
[[ "$GENERATE_CLAUDE" == true ]] && echo "  * CLAUDE.md"
[[ "$GENERATE_CLAUDE" == true ]] && echo "  * SESSION_DIARY.md"
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
if [[ ${#STATIC_VARS[@]} -gt 0 ]]; then
    echo "     Note: Scaffolded variables have '# shellcheck disable=SC2034' comments."
    echo "     Remove them once the variables are used in your script logic."
fi
if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then
    echo "  2. Test output: ./${SCRIPT_NAME}.sh"
    echo "  3. Add to Jamf Pro Extension Attributes"
else
    echo "  2. Test locally: sudo ./${SCRIPT_NAME}.sh"
fi
if [ "$IS_MONOREPO" = true ]; then
    echo "  $(if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then echo "4"; else echo "3"; fi). Bump version: bump-version ${SCRIPT_NAME}.sh patch \"Your changes\""
    echo "  $(if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then echo "5"; else echo "4"; fi). Commit: git commit -m \"Add ${SCRIPT_NAME} script\""
else
    echo "  $(if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then echo "4"; else echo "3"; fi). Bump version: bump-version patch \"Your changes\""
    echo "  $(if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then echo "5"; else echo "4"; fi). Commit & tag: git commit -am \"your message\" && git tag v1.0.1"
fi
echo ""

# Open VS Code
if command -v code &> /dev/null; then
    code "$PROJECT_DIR"
fi
