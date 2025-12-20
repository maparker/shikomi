#!/bin/bash

################################################################################
# SCRIPT:      shikomi.sh
# VERSION:     1.1.0
# AUTHOR:      Matt Parker
# DATE:        2025-12-07
# DESCRIPTION: Smart macOS/MDM Script Generator
#              - Detects if you are in an existing Git Repo (Monorepo mode)
#              - If not, creates a new Repo/Project (Micro-repo mode)
#              - Generates versioned scripts with semantic versioning
#              - Initializes Git + Pre-Commit Hooks + GitHub integration
################################################################################
# CHANGELOG
# 1.1.0 - 2025-12-20 - Added install.sh for PATH installation support
# 1.0.0 - 2025-12-07 - Initial release as Shikomi (rebranded from script_creator_pro)
################################################################################

# --- Script Metadata ---
readonly SCRIPT_VERSION="1.1.0"
readonly SCRIPT_NAME="shikomi"

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

echo "Target: $SCRIPT_PATH"
echo "Define Parameters (\$4-\$11). Press [Enter] on Label to finish."
echo ""

# --- 2. Interactive Wizard ---
declare -a BLOCK_HEADER
declare -a BLOCK_VARIABLES
declare -a BLOCK_LOGGING
declare -a README_ROWS
SECRETS_USED=false
declare -a SECRET_REMINDERS

for i in {4..11}; do
    echo "--- Parameter $i ---"
    read -rp "Label (e.g. 'Target Dept'): " param_label
    [[ -z "$param_label" ]] && break

    var_name=$(echo "$param_label" | tr '[:lower:]' '[:upper:]' | tr ' ' '_' | sed 's/[^A-Z0-9_]//g')

    read -rp "Is this a secret? (y/n): " is_secret

    if [[ "$is_secret" =~ ^[Yy] ]]; then
        SECRETS_USED=true
        BLOCK_HEADER+=("#   $var_name (Jamf: \$$i)")
        BLOCK_NORMALIZATION+=("$NORM_LINE")
        BLOCK_NORMALIZATION+=("${var_name}=\"\${${var_name}:-\$LOCAL_${var_name}}\"")

        # --- NEW SMART CHECK LOGIC START ---
        SECRETS_FILE="$HOME/.jamf_secrets"
        LOCAL_VAR_NAME="LOCAL_${var_name}"

        # Check if secrets file exists AND if the variable is defined in it
        if [[ -f "$SECRETS_FILE" ]] && grep -q "^${LOCAL_VAR_NAME}=" "$SECRETS_FILE"; then
            echo "   Found existing local secret: $LOCAL_VAR_NAME"
            BLOCK_LOGGING+=("log \"Config: $param_label [${var_name}]: ******* (Loaded from existing local secret)\"")
            README_ROWS+=("| $var_name | \$$i | \`$LOCAL_${var_name}\` (Existing) |")
        else
            echo "   Local secret missing. You will need to add it later."
            BLOCK_LOGGING+=("log \"Config: $param_label [${var_name}]: ******* (Masked)\"")
            SECRET_REMINDERS+=("${LOCAL_VAR_NAME}=\"REPLACE_WITH_REAL_SECRET\"")
            README_ROWS+=("| $var_name | \$$i | \`$LOCAL_${var_name}\` (Secret) |")
        fi
    else
        read -rp "Default Local Value: " param_default
        BLOCK_HEADER+=("#   \$$i: $param_label")
        BLOCK_VARIABLES+=("${var_name}=\"\${${i}:-\"${param_default}\"}\"")
        BLOCK_LOGGING+=("log \"Config: $param_label [${var_name}]: \$$var_name\"")

        # Add to README (Visible)
        README_ROWS+=("| $i | $param_label | \`$param_default\` |")
    fi
done

# --- 2.5. Static Configuration Variables (Non-Jamf Parameters) ---
echo ""
echo "--- Static Configuration Variables ---"
echo "These are hardcoded in the script (not MDM parameters)"
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
cat > "$SCRIPT_PATH" << EOF
#!/bin/zsh

################################################################################
# SCRIPT:      ${SCRIPT_NAME}.sh
# VERSION:     1.1.0
# AUTHOR:      $(git config user.name || echo "First Last")
# EMAIL:       $(git config user.email || echo "first.last@prizepicks.com")
# DATE:        $(date +%Y-%m-%d)
# Description: Fancy script that makes something cool happen on a Mac.
#
################################################################################
# PARAMETERS:
$(printf '%s\n' "${BLOCK_HEADER[@]}")
################################################################################
# CHANGELOG
# 1.1.0 - 2025-12-20 - Added install.sh for PATH installation support
# 1.0.0 - $(date +%Y-%m-%d) - Initial release
################################################################################

# --- Script Metadata ---
readonly SCRIPT_VERSION="1.1.0"
readonly SCRIPT_NAME="${SCRIPT_NAME}"

# --- Local Development Secrets ---
if [[ -f "\$HOME/.jamf_secrets" ]]; then
    source "\$HOME/.jamf_secrets"
fi

# --- Static Configuration ---
$(printf '%s\n' "${STATIC_VARS[@]}")

# --- Configuration (Jamf Parameters) ---
$(printf '%s\n' "${BLOCK_VARIABLES[@]}")

# --- Logging Setup ---
LOG_FILE="/var/log/${SCRIPT_NAME}.log"
function log() { echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$*"; }

# --- Main Logic ---
log "Starting \$SCRIPT_NAME v\$SCRIPT_VERSION..."
$(printf '%s\n' "${BLOCK_LOGGING[@]}")

log "----------------------------------------"
# TODO: Add logic here
log "\$SCRIPT_NAME completed successfully"
exit 0
EOF

chmod +x "$SCRIPT_PATH"

# --- 4. Generate README.md ---
echo "Generating README..."
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
1. Ensure \`~/.jamf_secrets\` exists (for secrets).
2. Run:
   \`\`\`bash
   sudo ./$SCRIPT_NAME.sh
   \`\`\`

## Versioning
This project uses [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes or incompatible API changes
- **MINOR**: New features, backward-compatible
- **PATCH**: Bug fixes, backward-compatible

To bump the version, use the provided version bump script:
\`\`\`bash
# Auto-detect script (typical usage)
./bump_version.sh [major|minor|patch] "Description of changes"

# Or specify script explicitly
./bump_version.sh $SCRIPT_NAME.sh [major|minor|patch] "Description"
\`\`\`
EOF

# --- 5. Generate Version Bump Utility ---
echo "Generating bump_version.sh..."

# For monorepo, create in current dir; for new project, create in project dir
if [ "$IS_MONOREPO" = true ]; then
    BUMP_PATH="$PROJECT_DIR/bump_version.sh"
else
    cd "$PROJECT_DIR" || exit
    BUMP_PATH="./bump_version.sh"
fi

cat > "$BUMP_PATH" << 'BUMP_EOF'
#!/bin/bash

################################################################################
# SCRIPT: bump_version.sh
# DESCRIPTION: Semantic version bumping utility for macOS/MDM scripts
#
# USAGE: ./bump_version.sh [SCRIPT_FILE] <major|minor|patch> "Change description"
#
# EXAMPLES:
#   Auto-detect script:
#     ./bump_version.sh patch "Fixed bug in parameter validation"
#
#   Specify script explicitly:
#     ./bump_version.sh my_script.sh minor "Added new feature"
################################################################################

set -euo pipefail

# Parse arguments - support both modes:
# Mode 1: ./bump_version.sh <bump_type> "description"  (auto-detect script)
# Mode 2: ./bump_version.sh <script.sh> <bump_type> "description"  (explicit script)

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

    # Find the main script (exclude bump_version.sh and any other utility scripts)
    # Strategy: Look for script with SCRIPT_VERSION constant (our generated scripts have this)
    SCRIPT_FILE=""
    shopt -s nullglob
    for file in *.sh; do
        if [[ "$file" != "bump_version.sh" ]] && grep -q "^readonly SCRIPT_VERSION=" "$file" 2>/dev/null; then
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

# Update version in script file header
sed -i.bak "s/^# VERSION:.*$/# VERSION:     $NEW_VERSION/" "$SCRIPT_FILE"

# Update SCRIPT_VERSION constant
sed -i.bak "s/^readonly SCRIPT_VERSION=.*$/readonly SCRIPT_VERSION=\"$NEW_VERSION\"/" "$SCRIPT_FILE"

# Update CHANGELOG in script header (add new entry at top)
CHANGELOG_LINE="# $NEW_VERSION - $TODAY - $CHANGE_DESC"
sed -i.bak "/^# CHANGELOG$/a\\
$CHANGELOG_LINE" "$SCRIPT_FILE"

# Update README.md version
sed -i.bak "s/^\*\*Version:\*\* .*$/\*\*Version:\*\* $NEW_VERSION/" README.md
sed -i.bak "s/^\*\*Last Updated:\*\* .*$/\*\*Last Updated:\*\* $TODAY/" README.md

# Update CHANGELOG.md (add new version section at top)
if [[ -f "CHANGELOG.md" ]]; then
    # Create temp file with new version entry
    {
        head -n 8 CHANGELOG.md
        echo ""
        echo "## [$NEW_VERSION] - $TODAY"
        echo ""
        case "$BUMP_TYPE" in
            major)
                echo "### Changed"
                echo "- $CHANGE_DESC"
                ;;
            minor)
                echo "### Added"
                echo "- $CHANGE_DESC"
                ;;
            patch)
                echo "### Fixed"
                echo "- $CHANGE_DESC"
                ;;
        esac
        echo ""
        tail -n +9 CHANGELOG.md
    } > CHANGELOG.md.tmp
    mv CHANGELOG.md.tmp CHANGELOG.md
fi

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
- Core functionality implemented
- Jamf Pro parameter support
$([ "$SECRETS_USED" = true ] && echo "- Secure secrets management via ~/.jamf_secrets")
EOF

# --- 6. Branching Git Logic ---

if [ "$IS_MONOREPO" = true ]; then
    # --- EXISTING REPO FLOW ---

    # 1. Safety Check: Are there uncommitted changes?
    if [[ -n $(git status --porcelain) ]]; then
        echo "Error: You have uncommitted changes in this repo."
        echo "   Please commit or stash them before creating a new script."
        exit 1
    fi

    # 2. Prompt for Branching
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
    git add "$SCRIPT_PATH" "$README_PATH" "$CHANGELOG_PATH" "$BUMP_PATH"

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
*.pkg
*.zip
EOF

# Install Pre-commit if available
if command -v pre-commit &> /dev/null; then
    cat > .pre-commit-config.yaml << EOF
repos:
-   repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
    -   id: gitleaks
EOF
    pre-commit install
    git add .pre-commit-config.yaml
else
    echo "   (Skipping pre-commit setup)"
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
          # Find versioned script (same logic as bump_version.sh)
          SCRIPT_FILE=""
          shopt -s nullglob
          for file in *.sh; do
            if [[ "\$file" != "bump_version.sh" ]] && grep -q "^readonly SCRIPT_VERSION=" "\$file" 2>/dev/null; then
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
echo ""
echo "Generated Files:"
echo "  * ${SCRIPT_NAME}.sh (v1.0.0)"
if [ "$IS_MONOREPO" = true ]; then
    echo "  * ${SCRIPT_NAME}_README.md"
    echo "  * ${SCRIPT_NAME}_CHANGELOG.md"
else
    echo "  * README.md"
    echo "  * CHANGELOG.md"
    echo "  * .gitignore"
    [[ -f ".github/workflows/validate-version.yml" ]] && echo "  * .github/workflows/validate-version.yml"
fi
echo "  * bump_version.sh"
echo ""

if [ "$SECRETS_USED" = true ]; then
    echo "WARNING: SECRETS CONFIGURATION NEEDED:"
    echo "Add these to ~/.jamf_secrets:"
    printf '   %s\n' "${SECRET_REMINDERS[@]}"
    echo ""
fi

echo "Quick Start:"
echo "  1. Edit your script: ${SCRIPT_NAME}.sh"
echo "  2. Test locally: sudo ./${SCRIPT_NAME}.sh"
if [ "$IS_MONOREPO" = true ]; then
    echo "  3. Bump version: ./bump_version.sh ${SCRIPT_NAME}.sh patch \"Your changes\""
    echo "  4. Commit: git commit -m \"Add ${SCRIPT_NAME} script\""
else
    echo "  3. Bump version: ./bump_version.sh patch \"Your changes\""
    echo "  4. Commit & tag: git commit -am \"your message\" && git tag v1.0.1"
fi
echo ""

# Open VS Code
if command -v code &> /dev/null; then
    code "$PROJECT_DIR"
fi
