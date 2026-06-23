################################################################################
# LIB:         git-setup.sh
# DESCRIPTION: Git initialization, branching, and GitHub setup for Shikomi
#
# FUNCTIONS:   init_new_repo(), create_feature_branch(), generate_gitignore(),
#              generate_precommit_config(), install_precommit_hooks(),
#              create_github_repo(), stage_monorepo_files(), stage_and_commit_new_repo()
#
# GLOBALS READ:
#   SCRIPT_NAME, SCRIPT_PATH, README_PATH, CHANGELOG_PATH,
#   GENERATE_SCAFFOLDING, PROJECT_DIR
#
# GLOBALS WRITTEN: None
################################################################################

function init_new_repo() {
    echo "Initializing Git..."
    git init -q
}

function create_feature_branch() {
    # Detect default branch (main or master)
    local default_branch
    default_branch=$(git remote show origin 2>/dev/null | sed -n '/HEAD branch/s/.*: //p')

    if [[ -z "$default_branch" ]]; then
        default_branch="main"
    fi

    echo "Switching to $default_branch and updating..."
    git checkout "$default_branch" 2>/dev/null || git checkout master 2>/dev/null || true
    git pull -q 2>/dev/null || true

    # Create new branch
    local branch_name="feature/$SCRIPT_NAME"
    echo "Creating branch: $branch_name"

    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        echo "Warning: Branch $branch_name already exists. Switching to it."
        git checkout "$branch_name"
    else
        git checkout -b "$branch_name"
    fi
}

function generate_gitignore() {
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
}

# Args: $1 = hook_level ("basic" or "enhanced")
function generate_precommit_config() {
    local hook_level="$1"

    if [[ "$hook_level" == "enhanced" ]]; then
        cat > .pre-commit-config.yaml << 'EOF'
repos:
  # Secret scanning with gitleaks
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks

  # Shell script linting (uses brew-installed shellcheck)
  - repo: local
    hooks:
      - id: shellcheck
        name: shellcheck
        language: system
        entry: shellcheck
        args: [--severity=warning]
        types: [shell]

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
}

function install_precommit_hooks() {
    # Wrapper that checks if pre-commit is available
    if command -v pre-commit &> /dev/null; then
        return 0  # Available
    else
        echo "   (Skipping pre-commit setup - 'pre-commit' not installed)"
        echo "   To enable: brew install pre-commit"
        return 1  # Not available
    fi
}

function create_github_repo() {
    if command -v gh &> /dev/null; then
        echo "Creating GitHub repository..."
        gh repo create "$SCRIPT_NAME" --private --source=. --remote=origin --push
        echo "Live at: $(gh repo view --json url -q .url)"
    fi
}

function stage_monorepo_files() {
    echo "Staging files..."
    if [ "$GENERATE_SCAFFOLDING" = true ]; then
        git add "$SCRIPT_PATH" "$README_PATH" "$CHANGELOG_PATH"
    else
        git add "$SCRIPT_PATH"
    fi

    # Stage Claude Code files if generated
    if [[ "${GENERATE_CLAUDE:-false}" == true ]]; then
        local repo_root
        repo_root=$(git rev-parse --show-toplevel)
        [[ -f "$repo_root/CLAUDE.md" ]] && git add "$repo_root/CLAUDE.md"
        [[ -f "$repo_root/SESSION_DIARY.md" ]] && git add "$repo_root/SESSION_DIARY.md"
    fi

    echo "Files staged on branch: $(git branch --show-current)"
    echo "   Next Step: git commit -m 'Add $SCRIPT_NAME script'"
}

function stage_and_commit_new_repo() {
    git add .
    git commit -m "Initial commit: Scaffolding for $SCRIPT_NAME"
}
