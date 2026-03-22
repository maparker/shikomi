#!/bin/bash

################################################################################
# SCRIPT:      add_security_tools.sh
# VERSION:     1.2.0
# AUTHOR:      Matt Parker
# DATE:        2025-12-07
# DESCRIPTION: Adds security tools and checks to an existing Git repository
#              - Pre-commit hooks (gitleaks, shellcheck)
#              - GitHub Actions workflows
#              - Pre-push version checks
#              - Enhanced .gitignore
################################################################################
# CHANGELOG
# 1.2.0 - 2026-03-22 - Added optional Jamf Pro deploy workflow for existing repos
# 1.1.0 - 2026-03-11 - Added basic/enhanced pre-commit hook level prompt matching shikomi
# 1.0.1 - 2026-01-19 - Fixed version template to prevent generated scripts from inheriting shikomi's version number
# 1.0.0 - 2025-12-07 - Initial versioned release
################################################################################

# --- Script Metadata ---
readonly SCRIPT_VERSION="1.2.0"
# shellcheck disable=SC2034
readonly SCRIPT_NAME="add_security_tools"

set -euo pipefail

# --- Version/Help Check ---
if [[ "${1:-}" == "--version" ]] || [[ "${1:-}" == "-v" ]]; then
    echo "add_security_tools v$SCRIPT_VERSION"
    exit 0
fi

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "add_security_tools v$SCRIPT_VERSION - Security tools installer"
    echo ""
    echo "Usage: $0"
    echo ""
    echo "Adds security tools to your Git repository:"
    echo "  - Pre-commit hooks (gitleaks, shellcheck)"
    echo "  - GitHub Actions workflows"
    echo "  - Enhanced .gitignore"
    echo ""
    echo "Options:"
    echo "  -v, --version    Show version"
    echo "  -h, --help       Show this help"
    exit 0
fi

echo "=============================================="
echo "   Adding Security Tools to Repository       "
echo "=============================================="
echo ""

# Check if we're in a Git repo
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    echo "ERROR: Not inside a Git repository"
    echo "Run this script from the root of your Git repo"
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

echo "Repository: $(basename "$REPO_ROOT")"
echo ""

# 1. Check for pre-commit
if ! command -v pre-commit &> /dev/null; then
    echo "WARNING: pre-commit not installed"
    echo "Install with: brew install pre-commit"
    echo ""
    read -rp "Continue without pre-commit? (y/n): " continue_without
    if [[ ! "$continue_without" =~ ^[Yy] ]]; then
        exit 1
    fi
    SKIP_PRECOMMIT=true
else
    SKIP_PRECOMMIT=false
fi

# 2. Create .pre-commit-config.yaml
if [[ "$SKIP_PRECOMMIT" == false ]]; then
    WRITE_CONFIG=true
    if [[ -f ".pre-commit-config.yaml" ]]; then
        echo "⚠️  .pre-commit-config.yaml already exists"
        read -rp "Overwrite? (y/n): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy] ]]; then
            echo "Skipping .pre-commit-config.yaml"
            WRITE_CONFIG=false
        fi
    fi

    if [[ "$WRITE_CONFIG" == true ]]; then
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
            echo "✓ Enhanced .pre-commit-config.yaml created (9 checks)"
        else
            # Basic: Just gitleaks for secret scanning
            cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
EOF
            echo "✓ Basic .pre-commit-config.yaml created (secrets only)"
        fi
    fi

    # Install hooks
    echo "Installing pre-commit hooks..."
    pre-commit install
    echo "✓ Pre-commit hooks installed"
    echo ""
fi

# 3. Create GitHub Actions workflows
echo "Creating GitHub Actions workflows..."
mkdir -p .github/workflows

cat > .github/workflows/security-checks.yml << 'EOF'
name: Security & Quality Checks

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  gitleaks:
    name: Secret Scanning
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  shellcheck:
    name: Shell Script Linting
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run ShellCheck
        uses: ludeeus/action-shellcheck@master
        with:
          severity: warning
          ignore_paths: .github

  version-consistency:
    name: Version Consistency Check
    runs-on: ubuntu-latest
    if: contains(github.event.head_commit.message, 'bump') || startsWith(github.ref, 'refs/tags/')
    steps:
      - uses: actions/checkout@v4

      - name: Check version consistency
        run: |
          echo "Checking for version mismatches..."

          # Find all versioned scripts
          FOUND_SCRIPTS=false
          for script in *.sh; do
            if grep -q "^readonly SCRIPT_VERSION=" "$script" 2>/dev/null; then
              FOUND_SCRIPTS=true
              SCRIPT_VERSION=$(grep "^readonly SCRIPT_VERSION=" "$script" | sed 's/.*"\(.*\)".*/\1/')
              README_FILE="${script%.*}_README.md"

              if [[ -f "$README_FILE" ]]; then
                README_VERSION=$(grep "^\*\*Version:\*\*" "$README_FILE" | sed 's/.*: \(.*\)$/\1/')

                if [[ "$SCRIPT_VERSION" != "$README_VERSION" ]]; then
                  echo "ERROR: Version mismatch in $script"
                  echo "  Script: $SCRIPT_VERSION"
                  echo "  README: $README_VERSION"
                  exit 1
                fi
                echo "✓ $script: $SCRIPT_VERSION"
              fi
            fi
          done

          if [[ "$FOUND_SCRIPTS" == false ]]; then
            echo "No versioned scripts found (skipping check)"
            exit 0
          fi

          echo "All versions consistent!"
EOF

echo "✓ .github/workflows/security-checks.yml created"
echo ""

# 3b. Optional: Jamf Pro deployment workflow
read -rp "Add GitHub Actions workflow to deploy scripts to Jamf Pro on merge? (y/n): " add_deploy
if [[ "$add_deploy" =~ ^[Yy] ]]; then
    echo "Generating Jamf Pro deploy workflow..."
    cat > .github/workflows/deploy-to-jamf.yml << 'EOF'
name: Deploy Script to Jamf Pro

on:
  push:
    branches: [ main, master ]
    paths:
      - '*.sh'
      - '!bump-version.sh'

permissions:
  contents: read

jobs:
  deploy:
    name: Deploy to Jamf Pro
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Find versioned script
        id: find_script
        run: |
          SCRIPT_FILE=""
          for file in *.sh; do
            if [[ "$file" != "bump-version.sh" ]] && grep -q "^readonly SCRIPT_VERSION=" "$file" 2>/dev/null; then
              SCRIPT_FILE="$file"
              break
            fi
          done

          if [[ -z "$SCRIPT_FILE" ]]; then
            echo "Error: No versioned script found"
            exit 1
          fi

          SCRIPT_NAME="${SCRIPT_FILE%.sh}"
          SCRIPT_VERSION=$(grep "^readonly SCRIPT_VERSION=" "$SCRIPT_FILE" | sed 's/.*"\(.*\)".*/\1/')

          echo "script_file=$SCRIPT_FILE" >> $GITHUB_OUTPUT
          echo "script_name=$SCRIPT_NAME" >> $GITHUB_OUTPUT
          echo "script_version=$SCRIPT_VERSION" >> $GITHUB_OUTPUT
          echo "Found: $SCRIPT_FILE (v$SCRIPT_VERSION)"

      - name: Authenticate to Jamf Pro
        id: auth
        env:
          JAMF_CLIENT_ID: ${{ secrets.JAMF_CLIENT_ID }}
          JAMF_CLIENT_SECRET: ${{ secrets.JAMF_CLIENT_SECRET }}
          JAMF_URL: ${{ secrets.JAMF_URL }}
        run: |
          if [[ -z "$JAMF_CLIENT_ID" || -z "$JAMF_CLIENT_SECRET" || -z "$JAMF_URL" ]]; then
            echo "Error: Missing required secrets (JAMF_CLIENT_ID, JAMF_CLIENT_SECRET, JAMF_URL)"
            exit 1
          fi

          RESPONSE=$(curl -s -X POST "${JAMF_URL}/api/oauth/token" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "client_id=${JAMF_CLIENT_ID}&client_secret=${JAMF_CLIENT_SECRET}&grant_type=client_credentials")

          TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')

          if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
            echo "Error: Failed to authenticate to Jamf Pro"
            echo "$RESPONSE" | jq .
            exit 1
          fi

          echo "::add-mask::$TOKEN"
          echo "token=$TOKEN" >> $GITHUB_OUTPUT
          echo "Authenticated to Jamf Pro"

      - name: Read script content
        id: script_content
        run: |
          SCRIPT_CONTENT=$(cat "${{ steps.find_script.outputs.script_file }}")
          echo "$SCRIPT_CONTENT" > /tmp/script_payload.txt
          echo "Script content read (${{ steps.find_script.outputs.script_file }})"

      - name: Look up existing script in Jamf Pro
        id: lookup
        env:
          JAMF_URL: ${{ secrets.JAMF_URL }}
        run: |
          SCRIPT_NAME="${{ steps.find_script.outputs.script_name }}"
          TOKEN="${{ steps.auth.outputs.token }}"

          # Search for script by name (try without .sh first, then with .sh)
          RESPONSE=$(curl -s -X GET "${JAMF_URL}/api/v1/scripts?filter=name==%22${SCRIPT_NAME}%22" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Accept: application/json")

          SCRIPT_ID=$(echo "$RESPONSE" | jq -r '.results[0].id // empty')

          if [[ -z "$SCRIPT_ID" ]]; then
            # Retry with .sh extension (in case Jamf Pro has the script stored with .sh)
            RESPONSE=$(curl -s -X GET "${JAMF_URL}/api/v1/scripts?filter=name==%22${SCRIPT_NAME}.sh%22" \
              -H "Authorization: Bearer ${TOKEN}" \
              -H "Accept: application/json")
            SCRIPT_ID=$(echo "$RESPONSE" | jq -r '.results[0].id // empty')
          fi

          if [[ -n "$SCRIPT_ID" ]]; then
            echo "Found existing script: $SCRIPT_NAME (ID: $SCRIPT_ID)"
            echo "action=update" >> $GITHUB_OUTPUT
            echo "script_id=$SCRIPT_ID" >> $GITHUB_OUTPUT
          else
            echo "Script not found in Jamf Pro, will create new"
            echo "action=create" >> $GITHUB_OUTPUT
          fi

      - name: Deploy script to Jamf Pro
        env:
          JAMF_URL: ${{ secrets.JAMF_URL }}
        run: |
          TOKEN="${{ steps.auth.outputs.token }}"
          SCRIPT_NAME="${{ steps.find_script.outputs.script_name }}"
          SCRIPT_VERSION="${{ steps.find_script.outputs.script_version }}"
          ACTION="${{ steps.lookup.outputs.action }}"
          SCRIPT_ID="${{ steps.lookup.outputs.script_id }}"

          PAYLOAD=$(jq -n \
            --arg name "$SCRIPT_NAME" \
            --arg info "Deployed from GitHub (v${SCRIPT_VERSION})" \
            --arg contents "$(cat /tmp/script_payload.txt)" \
            '{
              name: $name,
              info: $info,
              scriptContents: $contents,
              priority: "AFTER",
              categoryId: "-1"
            }')

          if [[ "$ACTION" == "update" ]]; then
            echo "Updating script $SCRIPT_NAME (ID: $SCRIPT_ID)..."
            HTTP_CODE=$(curl -s -o /tmp/response.json -w "%{http_code}" \
              -X PUT "${JAMF_URL}/api/v1/scripts/${SCRIPT_ID}" \
              -H "Authorization: Bearer ${TOKEN}" \
              -H "Content-Type: application/json" \
              -d "$PAYLOAD")
          else
            echo "Creating script $SCRIPT_NAME..."
            HTTP_CODE=$(curl -s -o /tmp/response.json -w "%{http_code}" \
              -X POST "${JAMF_URL}/api/v1/scripts" \
              -H "Authorization: Bearer ${TOKEN}" \
              -H "Content-Type: application/json" \
              -d "$PAYLOAD")
          fi

          if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
            echo "Successfully deployed $SCRIPT_NAME v${SCRIPT_VERSION} to Jamf Pro (HTTP $HTTP_CODE)"
          else
            echo "Error: Deployment failed (HTTP $HTTP_CODE)"
            cat /tmp/response.json | jq . 2>/dev/null || cat /tmp/response.json
            exit 1
          fi

      - name: Deployment summary
        if: always()
        run: |
          echo "## Deployment Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Script:** ${{ steps.find_script.outputs.script_name }}" >> $GITHUB_STEP_SUMMARY
          echo "**Version:** ${{ steps.find_script.outputs.script_version }}" >> $GITHUB_STEP_SUMMARY
          echo "**Action:** ${{ steps.lookup.outputs.action }}" >> $GITHUB_STEP_SUMMARY
          echo "**Commit:** ${{ github.sha }}" >> $GITHUB_STEP_SUMMARY
EOF

    echo "✓ .github/workflows/deploy-to-jamf.yml created"
    echo ""
    echo "Required GitHub Secrets for deployment:"
    echo "  JAMF_CLIENT_ID     - API client ID from Jamf Pro"
    echo "  JAMF_CLIENT_SECRET - API client secret from Jamf Pro"
    echo "  JAMF_URL           - Jamf Pro URL (e.g. https://yourinstance.jamfcloud.com)"
    DEPLOY_ADDED=true
else
    DEPLOY_ADDED=false
fi
echo ""

# 4. Create pre-push hook
echo "Creating pre-push hook..."
cat > .git/hooks/pre-push << 'EOF'
#!/bin/bash

echo "Running pre-push checks..."

# Check for uncommitted version changes
if git diff --name-only | grep -qE "(bump_version\.sh|.*_README\.md|CHANGELOG\.md)"; then
    echo "ERROR: You have uncommitted version-related changes"
    echo "Please commit all changes before pushing"
    exit 1
fi

# Check if any versioned scripts have mismatched versions
FOUND_MISMATCH=false
for script in *.sh; do
    if grep -q "^readonly SCRIPT_VERSION=" "$script" 2>/dev/null; then
        SCRIPT_VERSION=$(grep "^readonly SCRIPT_VERSION=" "$script" | sed 's/.*"\(.*\)".*/\1/')
        README_FILE="${script%.*}_README.md"

        if [[ -f "$README_FILE" ]]; then
            README_VERSION=$(grep "^\*\*Version:\*\*" "$README_FILE" | sed 's/.*: \(.*\)$/\1/')

            if [[ "$SCRIPT_VERSION" != "$README_VERSION" ]]; then
                echo "ERROR: Version mismatch in $script"
                echo "  Script: $SCRIPT_VERSION"
                echo "  README: $README_VERSION"
                echo "  Fix: ./bump_version.sh $script patch 'Sync version'"
                FOUND_MISMATCH=true
            fi
        fi
    fi
done

if [[ "$FOUND_MISMATCH" == true ]]; then
    exit 1
fi

echo "✓ Pre-push checks passed"
EOF

chmod +x .git/hooks/pre-push
echo "✓ Pre-push hook created"
echo ""

# 5. Update .gitignore
echo "Updating .gitignore..."
if [[ -f ".gitignore" ]]; then
    # Check if security section already exists
    if ! grep -q "# --- Security: Never commit secrets ---" .gitignore; then
        cat >> .gitignore << 'EOF'

# --- Security: Never commit secrets ---
.env
.env.*
.jamf_secrets
*secret*
*password*
*credentials*
*auth*.json
*.p8
*.pem
token.json
config.local

# --- macOS ---
.DS_Store
._*
.AppleDouble
.LSOverride

# --- Editors ---
.vscode/
.idea/
*.swp
*.bak

# --- Artifacts ---
*.dmg
*.pkg
*.zip
EOF
        echo "✓ .gitignore updated with security patterns"
    else
        echo "✓ .gitignore already contains security patterns"
    fi
else
    cat > .gitignore << 'EOF'
# --- Security: Never commit secrets ---
.env
.env.*
.jamf_secrets
*secret*
*password*
*credentials*
*auth*.json
*.p8
*.pem
token.json
config.local

# --- macOS ---
.DS_Store
._*
.AppleDouble
.LSOverride

# --- Editors ---
.vscode/
.idea/
*.swp
*.bak

# --- Artifacts ---
*.dmg
*.pkg
*.zip
EOF
    echo "✓ .gitignore created"
fi
echo ""

# 6. Test pre-commit on existing files
if [[ "$SKIP_PRECOMMIT" == false ]]; then
    echo "Testing pre-commit hooks on existing files..."
    read -rp "Run pre-commit on all files now? (y/n): " run_test
    if [[ "$run_test" =~ ^[Yy] ]]; then
        pre-commit run --all-files || true
    fi
    echo ""
fi

# 7. Summary
echo "=============================================="
echo "         Setup Complete!                      "
echo "=============================================="
echo ""
echo "Added Security Tools:"
if [[ "$SKIP_PRECOMMIT" == false ]]; then
    if [[ "${hook_level:-b}" =~ ^[Ee] ]]; then
        echo "  ✓ Pre-commit hooks - enhanced (gitleaks, shellcheck, 7 quality checks)"
    else
        echo "  ✓ Pre-commit hooks - basic (gitleaks only)"
    fi
fi
echo "  ✓ GitHub Actions workflows (security checks)"
if [[ "${DEPLOY_ADDED:-false}" == true ]]; then
    echo "  ✓ GitHub Actions workflow (Jamf Pro deployment)"
fi
echo "  ✓ Pre-push version checks"
echo "  ✓ Enhanced .gitignore"
echo ""
echo "What's Protected:"
echo "  🔒 Secrets detection (local & CI)"
echo "  🔒 Shell script quality checks"
echo "  🔒 Version consistency validation"
echo "  🔒 Large file prevention"
echo "  🔒 Private key detection"
echo ""
echo "Next Steps:"
echo "  1. Review .gitignore for your specific secrets"
echo "  2. Commit these changes:"
echo "     git add .pre-commit-config.yaml .github .gitignore .git/hooks/pre-push"
echo "     git commit -m 'chore: add security tools and checks'"
if [[ "${DEPLOY_ADDED:-false}" == true ]]; then
    echo "  3. Add required GitHub Secrets (JAMF_CLIENT_ID, JAMF_CLIENT_SECRET, JAMF_URL)"
fi
echo "  3. Push to enable GitHub Actions:"
echo "     git push"
if [[ "$SKIP_PRECOMMIT" == false ]]; then
    echo "  4. Test: Make a commit and watch hooks run!"
else
    echo "  4. Install pre-commit: brew install pre-commit"
    echo "     Then run: pre-commit install"
fi
echo ""
