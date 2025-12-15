#!/bin/bash

################################################################################
# SCRIPT:      bump_version.sh
# VERSION:     1.0.0
# AUTHOR:      Matt Parker
# DATE:        2025-12-07
# DESCRIPTION: Semantic version bumping utility for versioned scripts
#
# USAGE: ./bump_version.sh <SCRIPT_FILE> <major|minor|patch> "Change description"
#
# EXAMPLES:
#   ./bump_version.sh app_installer.sh patch "Fixed bug"
#   ./bump_version.sh backup_tool.sh minor "Added new feature"
################################################################################
# CHANGELOG
# 1.0.0 - 2025-12-07 - Initial versioned release
################################################################################

# --- Script Metadata ---
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="bump_version"

set -euo pipefail

# --- Version/Help Check ---
if [[ "${1:-}" == "--version" ]] || [[ "${1:-}" == "-v" ]]; then
    echo "bump_version v$SCRIPT_VERSION"
    exit 0
fi

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "bump_version v$SCRIPT_VERSION - Semantic version bumping utility"
    echo ""
    echo "Usage: $0 <script_file.sh> <major|minor|patch> \"Change description\""
    echo ""
    echo "Examples:"
    echo "  $0 app_installer.sh patch \"Fixed parameter validation\""
    echo "  $0 backup_tool.sh minor \"Added email notifications\""
    echo ""
    echo "Options:"
    echo "  -v, --version    Show version"
    echo "  -h, --help       Show this help"
    exit 0
fi

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <script_file.sh> <major|minor|patch> \"Change description\""
    echo ""
    echo "Examples:"
    echo "  $0 app_installer.sh patch \"Fixed parameter validation\""
    echo "  $0 backup_tool.sh minor \"Added email notifications\""
    echo "  $0 deployment.sh major \"Breaking change: Removed legacy mode\""
    exit 1
fi

SCRIPT_FILE="$1"
BUMP_TYPE="$2"
CHANGE_DESC="$3"

# Validate script file exists
if [[ ! -f "$SCRIPT_FILE" ]]; then
    echo "Error: Script file not found: $SCRIPT_FILE"
    exit 1
fi

# Validate it's a versioned script
if ! grep -q "^readonly SCRIPT_VERSION=" "$SCRIPT_FILE" 2>/dev/null; then
    echo "Error: $SCRIPT_FILE does not appear to be a versioned script"
    echo "Expected to find 'readonly SCRIPT_VERSION=' line"
    exit 1
fi

echo "Target script: $SCRIPT_FILE"
echo ""

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
echo ""

# Update version in script file header
sed -i.bak "s/^# VERSION:.*$/# VERSION:     $NEW_VERSION/" "$SCRIPT_FILE"

# Update SCRIPT_VERSION constant
sed -i.bak "s/^readonly SCRIPT_VERSION=.*$/readonly SCRIPT_VERSION=\"$NEW_VERSION\"/" "$SCRIPT_FILE"

# Update CHANGELOG in script header (add new entry after CHANGELOG line)
CHANGELOG_LINE="# $NEW_VERSION - $TODAY - $CHANGE_DESC"
sed -i.bak "/^# CHANGELOG$/a\\
$CHANGELOG_LINE" "$SCRIPT_FILE"

# Update README file if it exists
README_FILE="${SCRIPT_FILE%.*}_README.md"
if [[ -f "$README_FILE" ]]; then
    sed -i.bak "s/^\*\*Version:\*\* .*$/\*\*Version:\*\* $NEW_VERSION/" "$README_FILE"
    sed -i.bak "s/^\*\*Last Updated:\*\* .*$/\*\*Last Updated:\*\* $TODAY/" "$README_FILE"

    # Add to version history section
    VERSION_ENTRY="- $NEW_VERSION ($TODAY) - $CHANGE_DESC"
    if grep -q "^## Version History" "$README_FILE"; then
        sed -i.bak "/^## Version History$/a\\
$VERSION_ENTRY" "$README_FILE"
    fi
fi

# Clean up backup files
rm -f "$SCRIPT_FILE.bak" "$README_FILE.bak" 2>/dev/null || true

echo ""
echo "SUCCESS: Version bumped to $NEW_VERSION"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff $SCRIPT_FILE"
echo "  2. Commit changes: git add $SCRIPT_FILE ${README_FILE} && git commit -m \"chore: bump $SCRIPT_FILE to $NEW_VERSION\""
echo "  3. (Optional) Tag release: git tag -a \"${SCRIPT_FILE%.*}-v$NEW_VERSION\" -m \"$CHANGE_DESC\""
echo "  4. Push changes: git push && git push --tags"
