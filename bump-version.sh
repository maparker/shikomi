#!/bin/bash

################################################################################
# SCRIPT:      bump-version.sh
# VERSION:     1.2.0
# AUTHOR:      Matt Parker
# DATE:        2025-12-20
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
# CHANGELOG
# 1.2.0 - 2025-12-20 - Auto-detect mode and explicit script mode support
# 1.1.0 - 2025-12-20 - Added init command for bootstrapping versioning
# 1.0.0 - 2025-12-07 - Initial release
################################################################################

readonly SCRIPT_VERSION="1.2.0"

set -euo pipefail

# --- Version/Help Check ---
if [[ "${1:-}" == "--version" ]] || [[ "${1:-}" == "-v" ]]; then
    echo "bump-version v$SCRIPT_VERSION"
    exit 0
fi

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "bump-version v$SCRIPT_VERSION - Semantic version bumping utility"
    echo ""
    echo "Usage: bump-version [SCRIPT_FILE] <major|minor|patch> \"Change description\""
    echo ""
    echo "Auto-detect script:"
    echo "  bump-version patch \"Fixed bug in parameter validation\""
    echo "  bump-version minor \"Added new feature for user notifications\""
    echo "  bump-version major \"Breaking change: Removed deprecated parameters\""
    echo ""
    echo "Specify script explicitly:"
    echo "  bump-version my_script.sh patch \"Fixed bug\""
    echo "  bump-version another_script.sh minor \"Added feature\""
    echo ""
    echo "Options:"
    echo "  -v, --version    Show version"
    echo "  -h, --help       Show this help"
    exit 0
fi

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
