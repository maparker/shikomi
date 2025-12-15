#!/bin/bash

################################################################################
# SCRIPT:      add_security_tools.sh
# VERSION:     1.0.0
# AUTHOR:      Matt Parker
# DATE:        2025-12-07
# DESCRIPTION: Adds security tools and checks to an existing Git repository
#              - Pre-commit hooks (gitleaks, shellcheck)
#              - GitHub Actions workflows
#              - Pre-push version checks
#              - Enhanced .gitignore
################################################################################
# CHANGELOG
# 1.0.0 - 2025-12-07 - Initial versioned release
################################################################################

# --- Script Metadata ---
readonly SCRIPT_VERSION="1.0.0"
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
    if [[ -f ".pre-commit-config.yaml" ]]; then
        echo "⚠️  .pre-commit-config.yaml already exists"
        read -rp "Overwrite? (y/n): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy] ]]; then
            echo "Skipping .pre-commit-config.yaml"
        else
            echo "Creating .pre-commit-config.yaml..."
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
            echo "✓ .pre-commit-config.yaml created"
        fi
    else
        echo "Creating .pre-commit-config.yaml..."
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
        echo "✓ .pre-commit-config.yaml created"
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
    echo "  ✓ Pre-commit hooks (gitleaks, shellcheck)"
fi
echo "  ✓ GitHub Actions workflows"
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
echo "     git add .pre-commit-config.yaml .github .gitignore"
echo "     git commit -m 'chore: add security tools and checks'"
echo "  3. Push to enable GitHub Actions:"
echo "     git push"
if [[ "$SKIP_PRECOMMIT" == false ]]; then
    echo "  4. Test: Make a commit and watch hooks run!"
else
    echo "  4. Install pre-commit: brew install pre-commit"
    echo "     Then run: pre-commit install"
fi
echo ""
