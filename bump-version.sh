#!/bin/bash

################################################################################
# SCRIPT:      bump_version.sh
# VERSION:     1.2.0
# AUTHOR:      Matt Parker
# DATE:        2025-12-07
# DESCRIPTION: Semantic version bumping utility for versioned scripts
#
# USAGE: ./bump_version.sh <SCRIPT_FILE> <major|minor|patch|init> "Change description"
#
# EXAMPLES:
#   ./bump_version.sh app_installer.sh init "Initial versioned release"
#   ./bump_version.sh app_installer.sh patch "Fixed bug"
#   ./bump_version.sh backup_tool.sh minor "Added new feature"
################################################################################
# CHANGELOG
# 1.2.0 - 2025-12-20 - Enhanced init to detect and extract metadata from existing headers
# 1.1.0 - 2025-12-20 - Added init command to initialize versioning for unversioned scripts
# 1.0.0 - 2025-12-07 - Initial versioned release
################################################################################

# --- Script Metadata ---
readonly SCRIPT_VERSION="1.2.0"
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
    echo "Usage: $0 <script_file.sh> <major|minor|patch|init> \"Change description\""
    echo ""
    echo "Commands:"
    echo "  init      Initialize versioning for an unversioned script (sets to 1.0.0)"
    echo "  major     Bump major version (X.0.0) - breaking changes"
    echo "  minor     Bump minor version (x.X.0) - new features"
    echo "  patch     Bump patch version (x.x.X) - bug fixes"
    echo ""
    echo "Examples:"
    echo "  $0 app_installer.sh init \"Initial versioned release\""
    echo "  $0 app_installer.sh patch \"Fixed parameter validation\""
    echo "  $0 backup_tool.sh minor \"Added email notifications\""
    echo "  $0 deployment.sh major \"Breaking change: Removed legacy mode\""
    echo ""
    echo "Options:"
    echo "  -v, --version    Show version"
    echo "  -h, --help       Show this help"
    exit 0
fi

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <script_file.sh> <major|minor|patch|init> \"Change description\""
    echo ""
    echo "Examples:"
    echo "  $0 app_installer.sh init \"Initial versioned release\""
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

# Handle init command for unversioned scripts
if [[ "$BUMP_TYPE" == "init" ]]; then
    # Check if already versioned
    if grep -q "^readonly SCRIPT_VERSION=" "$SCRIPT_FILE" 2>/dev/null; then
        EXISTING_VERSION=$(grep "^readonly SCRIPT_VERSION=" "$SCRIPT_FILE" | sed 's/.*"\(.*\)".*/\1/')
        echo "Error: $SCRIPT_FILE is already versioned (v$EXISTING_VERSION)"
        echo "Use 'patch', 'minor', or 'major' to bump the version instead"
        exit 1
    fi

    echo "Initializing versioning for: $SCRIPT_FILE"
    echo ""

    INIT_VERSION="1.0.0"
    TODAY=$(date +%Y-%m-%d)

    # Extract script name from filename
    TARGET_SCRIPT_NAME=$(basename "$SCRIPT_FILE" .sh)

    # Read the first line (shebang)
    SHEBANG=$(head -n 1 "$SCRIPT_FILE")

    # Detect and parse existing header block (consecutive comment lines after shebang)
    HEADER_END_LINE=1
    EXISTING_DESCRIPTION=""
    EXISTING_AUTHOR=""
    EXISTING_USAGE=""

    # Find where the header block ends (first non-comment, non-blank line after shebang)
    line_num=2
    while IFS= read -r line; do
        # Skip empty lines and comment lines
        if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            HEADER_END_LINE=$line_num

            # Extract metadata from comments
            if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*[Dd]escription:[[:space:]]*(.+)$ ]]; then
                EXISTING_DESCRIPTION="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*#[[:space:]]*[Dd][Ee][Ss][Cc]:[[:space:]]*(.+)$ ]]; then
                EXISTING_DESCRIPTION="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*#[[:space:]]*[Aa]uthor:[[:space:]]*(.+)$ ]]; then
                EXISTING_AUTHOR="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*#[[:space:]]*[Uu]sage:[[:space:]]*(.+)$ ]]; then
                EXISTING_USAGE="${BASH_REMATCH[1]}"
            fi
        else
            # Found first non-comment line, stop here
            break
        fi
        line_num=$((line_num + 1))
    done < <(tail -n +2 "$SCRIPT_FILE")

    # Read the actual code (everything after the header block)
    if [[ $HEADER_END_LINE -gt 1 ]]; then
        REST_OF_FILE=$(tail -n +$((HEADER_END_LINE + 1)) "$SCRIPT_FILE")
        echo "Detected existing header (lines 2-$HEADER_END_LINE) - will be replaced"
        [[ -n "$EXISTING_DESCRIPTION" ]] && echo "  Found description: $EXISTING_DESCRIPTION"
        [[ -n "$EXISTING_AUTHOR" ]] && echo "  Found author: $EXISTING_AUTHOR"
        [[ -n "$EXISTING_USAGE" ]] && echo "  Found usage: $EXISTING_USAGE"
        echo ""
    else
        REST_OF_FILE=$(tail -n +2 "$SCRIPT_FILE")
    fi

    # Use extracted info or defaults
    FINAL_DESCRIPTION="${EXISTING_DESCRIPTION:-(Add description here)}"
    FINAL_AUTHOR="${EXISTING_AUTHOR:-Matt Parker}"
    FINAL_USAGE="${EXISTING_USAGE:-./$SCRIPT_FILE [options]}"

    # Create the version header block
    VERSION_HEADER="
################################################################################
# SCRIPT:      $TARGET_SCRIPT_NAME.sh
# VERSION:     1.2.0
# AUTHOR:      $FINAL_AUTHOR
# DATE:        $TODAY
# DESCRIPTION: $FINAL_DESCRIPTION
#
# USAGE: $FINAL_USAGE
################################################################################
# CHANGELOG
# 1.2.0 - 2025-12-20 - Enhanced init to detect and extract metadata from existing headers
# $INIT_VERSION - $TODAY - $CHANGE_DESC
################################################################################

# --- Script Metadata ---
readonly SCRIPT_VERSION="1.2.0"
readonly SCRIPT_NAME=\"$TARGET_SCRIPT_NAME\"
"

    # Create new file content
    NEW_CONTENT="${SHEBANG}${VERSION_HEADER}${REST_OF_FILE}"

    # Backup original file
    cp "$SCRIPT_FILE" "${SCRIPT_FILE}.bak"

    # Write new content
    echo "$NEW_CONTENT" > "$SCRIPT_FILE"

    echo "SUCCESS: Initialized $SCRIPT_FILE with version $INIT_VERSION"
    echo ""
    echo "Next steps:"
    echo "  1. Edit the DESCRIPTION field in the header"
    echo "  2. Update the USAGE field as needed"
    echo "  3. Review changes: git diff $SCRIPT_FILE"
    echo "  4. Commit changes: git add $SCRIPT_FILE && git commit -m \"chore: initialize versioning for $SCRIPT_FILE\""
    echo ""
    echo "Backup saved as: ${SCRIPT_FILE}.bak"

    exit 0
fi

# Validate it's a versioned script
if ! grep -q "^readonly SCRIPT_VERSION=" "$SCRIPT_FILE" 2>/dev/null; then
    echo "Error: $SCRIPT_FILE does not appear to be a versioned script"
    echo "Expected to find 'readonly SCRIPT_VERSION=' line"
    echo ""
    echo "To initialize versioning, run:"
    echo "  $0 $SCRIPT_FILE init \"Initial versioned release\""
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
