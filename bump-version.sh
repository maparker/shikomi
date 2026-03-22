#!/bin/bash

################################################################################
# SCRIPT: bump-version.sh
# VERSION:     1.2.0
# DESCRIPTION: Semantic version bumping utility for macOS/MDM scripts
#
# USAGE: ./bump-version.sh [SCRIPT_FILE] <major|minor|patch> "Change description" [--commit]
#
# OPTIONS:
#   --commit    Stage and commit all version changes automatically
#
# EXAMPLES:
#   Auto-detect script:
#     ./bump-version.sh patch "Fixed bug in parameter validation"
#     ./bump-version.sh patch "Fixed bug in parameter validation" --commit
#
#   Specify script explicitly:
#     ./bump-version.sh my_script.sh minor "Added new feature"
#     ./bump-version.sh my_script.sh minor "Added new feature" --commit
################################################################################
# CHANGELOG
# 1.2.0 - 2026-03-20 - Added --commit flag for automatic staging and committing of version bumps
# 1.1.0 - 2026-01-18 - Added munkipkg build-info support for automatic package version updates
# 1.0.1 - 2026-01-09 - Fixed file permissions to 755 for proper execution
# 1.0.0 - 2025-12-20 - Initial release
################################################################################

set -euo pipefail

readonly SCRIPT_VERSION="1.2.0"

# --- 0. Version/Help Check ---
if [[ "${1:-}" == "--version" ]] || [[ "${1:-}" == "-v" ]]; then
    echo "bump-version v$SCRIPT_VERSION"
    exit 0
fi

# --- BEGIN PORTABLE ---

# Check for --commit flag (can appear as last argument)
AUTO_COMMIT=false
args=("$@")
clean_args=()
for arg in "${args[@]}"; do
    if [[ "$arg" == "--commit" ]]; then
        AUTO_COMMIT=true
    else
        clean_args+=("$arg")
    fi
done
set -- "${clean_args[@]}"

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

# Resolve README and CHANGELOG paths
# Micro-repo: README.md / CHANGELOG.md
# Monorepo with scaffolding: {script_name}_README.md / {script_name}_CHANGELOG.md
SCRIPT_BASENAME="${SCRIPT_FILE%.sh}"
if [[ -f "README.md" ]]; then
    README_FILE="README.md"
elif [[ -f "${SCRIPT_BASENAME}_README.md" ]]; then
    README_FILE="${SCRIPT_BASENAME}_README.md"
else
    README_FILE=""
fi

if [[ -f "CHANGELOG.md" ]]; then
    CHANGELOG_FILE="CHANGELOG.md"
elif [[ -f "${SCRIPT_BASENAME}_CHANGELOG.md" ]]; then
    CHANGELOG_FILE="${SCRIPT_BASENAME}_CHANGELOG.md"
else
    CHANGELOG_FILE=""
fi

# Update README version (if it exists)
if [[ -n "$README_FILE" ]]; then
    sed -i.bak "s/^\*\*Version:\*\* .*$/\*\*Version:\*\* $NEW_VERSION/" "$README_FILE"
    sed -i.bak "s/^\*\*Last Updated:\*\* .*$/\*\*Last Updated:\*\* $TODAY/" "$README_FILE"
else
    echo "Note: No README found, skipping README version update"
fi

# Update CHANGELOG (insert new version section before first existing version entry)
if [[ -n "$CHANGELOG_FILE" ]]; then
    # Build the new entry block
    NEW_ENTRY="## [$NEW_VERSION] - $TODAY\n"
    case "$BUMP_TYPE" in
        major) NEW_ENTRY+="\n### Changed\n- $CHANGE_DESC\n" ;;
        minor) NEW_ENTRY+="\n### Added\n- $CHANGE_DESC\n" ;;
        patch) NEW_ENTRY+="\n### Fixed\n- $CHANGE_DESC\n" ;;
    esac

    # Insert before the first '## [' version heading
    if grep -q "^## \[" "$CHANGELOG_FILE"; then
        sed -i.bak "0,/^## \[/{s/^## \[/${NEW_ENTRY}\n## [/}" "$CHANGELOG_FILE"
    else
        # No existing version entries — append to end
        printf '\n%b\n' "$NEW_ENTRY" >> "$CHANGELOG_FILE"
    fi
else
    echo "Note: No CHANGELOG found, skipping CHANGELOG version update"
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
rm -f "$SCRIPT_FILE.bak" 2>/dev/null || true
[[ -n "$README_FILE" ]] && rm -f "${README_FILE}.bak" 2>/dev/null || true
[[ -n "$CHANGELOG_FILE" ]] && rm -f "${CHANGELOG_FILE}.bak" 2>/dev/null || true

echo ""
echo "SUCCESS: Version bumped to $NEW_VERSION"
echo ""

if [[ "$AUTO_COMMIT" == true ]]; then
    # Build list of files that bump-version touched
    BUMP_FILES=("$SCRIPT_FILE")
    [[ -n "$README_FILE" ]] && BUMP_FILES+=("$README_FILE")
    [[ -n "$CHANGELOG_FILE" ]] && BUMP_FILES+=("$CHANGELOG_FILE")
    for build_info_path in build-info.json pkg/build-info.json build/build-info.json build-info.plist pkg/build-info.plist build/build-info.plist; do
        [[ -f "$build_info_path" ]] && BUMP_FILES+=("$build_info_path")
    done

    # Stage only the files bump-version touched (ignore other uncommitted changes)
    echo "Staging and committing version bump..."
    git add "${BUMP_FILES[@]}"
    git commit -m "chore: bump version to $NEW_VERSION — $CHANGE_DESC"

    echo ""
    echo "Next steps:"
    echo "  1. Tag release: git tag -a \"v$NEW_VERSION\" -m \"$CHANGE_DESC\""
    echo "  2. Push changes: git push && git push --tags"
else
    echo "Next steps:"
    echo "  1. Review changes: git diff"
    echo "  2. Commit changes: git add . && git commit -m \"chore: bump version to $NEW_VERSION\""
    echo "  3. Tag release: git tag -a \"v$NEW_VERSION\" -m \"$CHANGE_DESC\""
    echo "  4. Push changes: git push && git push --tags"
fi
# --- END PORTABLE ---
