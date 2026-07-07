#!/bin/bash

################################################################################
# SCRIPT: bump-version.sh
# VERSION:     1.3.0
# DESCRIPTION: Semantic version bumping utility for macOS/MDM scripts
#
# USAGE: ./bump-version.sh [SCRIPT_FILE] <major|minor|patch> "Change description" [--commit]
#        ./bump-version.sh <SCRIPT_FILE> init "Initial release" [X.Y.Z] [--commit]
#
# OPTIONS:
#   --commit    Stage and commit all version changes automatically
#
# EXAMPLES:
#   Auto-detect script (picks the most recently modified versioned .sh file):
#     ./bump-version.sh patch "Fixed bug in parameter validation"
#     ./bump-version.sh patch "Fixed bug in parameter validation" --commit
#
#   Specify script explicitly:
#     ./bump-version.sh my_script.sh minor "Added new feature"
#     ./bump-version.sh my_script.sh minor "Added new feature" --commit
################################################################################
# CHANGELOG
# 1.3.0 - 2026-06-23 - Add init subcommand to inject versioning into existing unversioned scripts
# 1.2.4 - 2026-06-19 - Add --help/-h flag support
# 1.2.3 - 2026-04-29 - Fix in-script changelog insertion using awk instead of BSD-incompatible sed 0,/pattern/
# 1.2.2 - 2026-04-29 - Add History block support for EA scripts alongside CHANGELOG
# 1.2.1 - 2026-04-01 - Auto-detect now selects most recently modified script instead of first alphabetically
# 1.2.0 - 2026-03-20 - Added --commit flag for automatic staging and committing of version bumps
# 1.1.0 - 2026-01-18 - Added munkipkg build-info support for automatic package version updates
# 1.0.1 - 2026-01-09 - Fixed file permissions to 755 for proper execution
# 1.0.0 - 2025-12-20 - Initial release
################################################################################

set -euo pipefail

readonly SCRIPT_VERSION="1.3.0"

# --- 0. Version/Help Check ---
if [[ "${1:-}" == "--version" ]] || [[ "${1:-}" == "-v" ]]; then
    echo "bump-version v$SCRIPT_VERSION"
    exit 0
fi

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Usage: $(basename "$0") [SCRIPT_FILE] <major|minor|patch> \"Change description\" [--commit]"
    echo "       $(basename "$0") <SCRIPT_FILE> init \"Initial release\" [X.Y.Z] [--commit]"
    echo ""
    echo "Auto-detect (targets the most recently modified versioned .sh file):"
    echo "  $(basename "$0") patch \"Fixed bug in parameter validation\""
    echo "  $(basename "$0") minor \"Added new feature for user notifications\""
    echo "  $(basename "$0") major \"Breaking change: Removed deprecated parameters\""
    echo ""
    echo "Specify script explicitly:"
    echo "  $(basename "$0") my_script.sh patch \"Fixed bug\""
    echo "  $(basename "$0") another_script.sh minor \"Added feature\""
    echo ""
    echo "Initialize versioning in an existing unversioned script:"
    echo "  $(basename "$0") my_script.sh init \"Initial release\""
    echo "  $(basename "$0") my_script.sh init \"Initial release\" 2.1.0"
    echo ""
    echo "Prerequisites for init:"
    echo "  The target script must contain 'set -euo pipefail' (or 'set -uo pipefail'"
    echo "  for Extension Attributes). It anchors the readonly SCRIPT_VERSION= injection"
    echo "  and is the standard safe-mode declaration for all versioned scripts."
    echo ""
    echo "Options:"
    echo "  --commit    Stage and commit all version changes automatically"
    echo "  --version   Show version"
    echo "  --help      Show this help"
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

INIT_VERSION="1.0.0"
TODAY=$(date +%Y-%m-%d)

# Parse arguments - support both modes:
# Mode 1: ./bump-version.sh <bump_type> "description"  (auto-detect script)
# Mode 2: ./bump-version.sh <script.sh> <bump_type> "description"  (explicit script)
# Mode 3: ./bump-version.sh <script.sh> init "description" [X.Y.Z]  (init versioning)

if [[ $# -eq 3 ]]; then
    # Mode 2/3: Script explicitly specified
    SCRIPT_FILE="$1"
    BUMP_TYPE="$2"
    CHANGE_DESC="$3"

    if [[ ! -f "$SCRIPT_FILE" ]]; then
        echo "Error: Script file not found: $SCRIPT_FILE"
        exit 1
    fi

    if [[ "$BUMP_TYPE" == "init" ]]; then
        if grep -q "^readonly SCRIPT_VERSION=" "$SCRIPT_FILE" 2>/dev/null; then
            echo "Error: $SCRIPT_FILE is already versioned"
            echo "Use: bump-version $SCRIPT_FILE patch|minor|major \"description\""
            exit 1
        fi
    elif ! grep -q "^readonly SCRIPT_VERSION=" "$SCRIPT_FILE" 2>/dev/null; then
        echo "Error: $SCRIPT_FILE does not appear to be a versioned script"
        echo "Expected to find 'readonly SCRIPT_VERSION=' line"
        exit 1
    fi

    echo "Target script: $SCRIPT_FILE (explicitly specified)"
    echo ""

elif [[ $# -eq 4 ]]; then
    # Mode 3 with explicit starting version: script.sh init "description" X.Y.Z
    SCRIPT_FILE="$1"
    BUMP_TYPE="$2"
    CHANGE_DESC="$3"
    INIT_VERSION="$4"

    if [[ "$BUMP_TYPE" != "init" ]]; then
        echo "Usage: $0 [SCRIPT_FILE] <major|minor|patch> \"Change description\""
        echo "       $0 <SCRIPT_FILE> init \"Initial release\" [X.Y.Z]"
        exit 1
    fi

    if [[ ! -f "$SCRIPT_FILE" ]]; then
        echo "Error: Script file not found: $SCRIPT_FILE"
        exit 1
    fi

    if ! [[ "$INIT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid version format: $INIT_VERSION (expected X.Y.Z)"
        exit 1
    fi

    if grep -q "^readonly SCRIPT_VERSION=" "$SCRIPT_FILE" 2>/dev/null; then
        echo "Error: $SCRIPT_FILE is already versioned"
        echo "Use: bump-version $SCRIPT_FILE patch|minor|major \"description\""
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
    # When multiple candidates exist, pick the most recently modified one
    SCRIPT_FILE=""
    SCRIPT_MTIME=0
    CANDIDATE_COUNT=0
    CANDIDATES=()
    shopt -s nullglob
    for file in *.sh; do
        if [[ "$file" != "bump-version.sh" ]] && grep -q "^readonly SCRIPT_VERSION=" "$file" 2>/dev/null; then
            CANDIDATES+=("$file")
            CANDIDATE_COUNT=$((CANDIDATE_COUNT + 1))
            # Get modification time as epoch seconds (macOS stat)
            FILE_MTIME=$(stat -f "%m" "$file" 2>/dev/null) || FILE_MTIME=0
            if [[ "$FILE_MTIME" -gt "$SCRIPT_MTIME" ]]; then
                SCRIPT_MTIME="$FILE_MTIME"
                SCRIPT_FILE="$file"
            fi
        fi
    done

    if [[ "$CANDIDATE_COUNT" -gt 1 ]]; then
        echo "Warning: Multiple versioned scripts found:"
        for c in "${CANDIDATES[@]}"; do
            if [[ "$c" == "$SCRIPT_FILE" ]]; then
                echo "  - $c (most recently modified)"
            else
                echo "  - $c"
            fi
        done
        echo ""
        echo "Using: $SCRIPT_FILE (most recently modified)"
        echo "Tip: Specify the script explicitly: $0 <script.sh> $BUMP_TYPE \"$CHANGE_DESC\""
    fi

    if [[ -z "$SCRIPT_FILE" ]]; then
        echo "Error: No versioned script found in current directory"
        echo "Expected to find a .sh file with 'readonly SCRIPT_VERSION=' line"
        exit 1
    fi

    echo "Target script: $SCRIPT_FILE (auto-detected)"
    echo ""

else
    echo "Usage: $0 [SCRIPT_FILE] <major|minor|patch> \"Change description\""
    echo "       $0 <SCRIPT_FILE> init \"Initial release\" [X.Y.Z]"
    echo ""
    echo "Auto-detect (targets the most recently modified versioned .sh file):"
    echo "  $0 patch \"Fixed bug in parameter validation\""
    echo "  $0 minor \"Added new feature for user notifications\""
    echo "  $0 major \"Breaking change: Removed deprecated parameters\""
    echo ""
    echo "Specify script explicitly:"
    echo "  $0 my_script.sh patch \"Fixed bug\""
    echo "  $0 another_script.sh minor \"Added feature\""
    echo ""
    echo "Initialize versioning in an existing unversioned script:"
    echo "  $0 my_script.sh init \"Initial release\""
    echo "  $0 my_script.sh init \"Initial release\" 2.1.0"
    exit 1
fi

# --- Handle init subcommand ---
if [[ "$BUMP_TYPE" == "init" ]]; then
    IS_EA=false
    [[ "$SCRIPT_FILE" == *_ea.sh ]] && IS_EA=true

    if [[ "$IS_EA" == true ]]; then
        PIPEFAIL_LINE="set -uo pipefail"
    else
        PIPEFAIL_LINE="set -euo pipefail"
    fi

    SUGGEST_PIPEFAIL=false
    if ! grep -q "pipefail" "$SCRIPT_FILE"; then
        SUGGEST_PIPEFAIL=true
    fi

    DIVIDER=$(grep -E "^#{8,}" "$SCRIPT_FILE" 2>/dev/null | head -1 || echo "################################################################################")

    # Inject # VERSION: into header
    if ! grep -q "^# VERSION:" "$SCRIPT_FILE"; then
        if grep -q "^# SCRIPT:" "$SCRIPT_FILE"; then
            awk -v ver="$INIT_VERSION" '
                /^# SCRIPT:/ && !done { print; printf "# VERSION:     %s\n", ver; done=1; next }
                { print }
            ' "$SCRIPT_FILE" > "${SCRIPT_FILE}.tmp" && mv "${SCRIPT_FILE}.tmp" "$SCRIPT_FILE"
        else
            COMMENT_END=$(awk '
                NR == 1 { next }
                /^[[:space:]]*$/ && comment_seen { exit }
                /^#/ { last=NR; comment_seen=1 }
                !/^#/ && NF > 0 { exit }
                END { print last+0 }
            ' "$SCRIPT_FILE")
            INSERT_AFTER="${COMMENT_END:-1}"
            awk -v line="$INSERT_AFTER" -v ver="$INIT_VERSION" '
                NR == line { print; print "# VERSION:     " ver; next }
                { print }
            ' "$SCRIPT_FILE" > "${SCRIPT_FILE}.tmp" && mv "${SCRIPT_FILE}.tmp" "$SCRIPT_FILE"
        fi
    fi

    # Inject CHANGELOG/History section
    if ! grep -qE "^# CHANGELOG$|^# History$" "$SCRIPT_FILE"; then
        SAFEMODELINENO=$(grep -n "^set -" "$SCRIPT_FILE" | grep "pipefail" | head -1 | cut -d: -f1) || true
        LIMIT="${SAFEMODELINENO:-999999}"
        LAST_DIVIDER=$(awk -v limit="$LIMIT" 'NR < limit && /^#{8,}/ { last=NR } END { print last+0 }' "$SCRIPT_FILE")
        ENTRY_FILE=$(mktemp)
        if [[ "$LAST_DIVIDER" -gt 0 ]]; then
            # Existing divider acts as the closing line
            if [[ "$IS_EA" == true ]]; then
                printf "%s\n#\n# History\n# %s - %s - %s\n#\n" "$DIVIDER" "$INIT_VERSION" "$TODAY" "$CHANGE_DESC" > "$ENTRY_FILE"
            else
                printf "%s\n# CHANGELOG\n# %s - %s - %s\n" "$DIVIDER" "$INIT_VERSION" "$TODAY" "$CHANGE_DESC" > "$ENTRY_FILE"
            fi
            head -n "$((LAST_DIVIDER - 1))" "$SCRIPT_FILE" > "${SCRIPT_FILE}.tmp"
            cat "$ENTRY_FILE" >> "${SCRIPT_FILE}.tmp"
            tail -n +"$LAST_DIVIDER" "$SCRIPT_FILE" >> "${SCRIPT_FILE}.tmp"
        else
            # No divider — insert self-contained block before set -pipefail or first code line
            if [[ "$IS_EA" == true ]]; then
                printf "%s\n#\n# History\n# %s - %s - %s\n#\n%s\n" "$DIVIDER" "$INIT_VERSION" "$TODAY" "$CHANGE_DESC" "$DIVIDER" > "$ENTRY_FILE"
            else
                printf "%s\n# CHANGELOG\n# %s - %s - %s\n%s\n" "$DIVIDER" "$INIT_VERSION" "$TODAY" "$CHANGE_DESC" "$DIVIDER" > "$ENTRY_FILE"
            fi
            INSERT_BEFORE=$(awk '
                NR == 1 { next }
                !/^[[:space:]]*$/ && !/^#/ { print NR; exit }
                END { print NR+1 }
            ' "$SCRIPT_FILE")
            head -n "$((INSERT_BEFORE - 1))" "$SCRIPT_FILE" > "${SCRIPT_FILE}.tmp"
            cat "$ENTRY_FILE" >> "${SCRIPT_FILE}.tmp"
            tail -n +"$INSERT_BEFORE" "$SCRIPT_FILE" >> "${SCRIPT_FILE}.tmp"
        fi
        mv "${SCRIPT_FILE}.tmp" "$SCRIPT_FILE"
        rm -f "$ENTRY_FILE"
    fi

    # Inject readonly SCRIPT_VERSION= — after pipefail if present, else before first code line
    if ! grep -q "^readonly SCRIPT_VERSION=" "$SCRIPT_FILE"; then
        if [[ "$SUGGEST_PIPEFAIL" == false ]]; then
            awk -v ver="$INIT_VERSION" '
                /pipefail/ && !done { print; print "readonly SCRIPT_VERSION=\"" ver "\""; done=1; next }
                { print }
            ' "$SCRIPT_FILE" > "${SCRIPT_FILE}.tmp" && mv "${SCRIPT_FILE}.tmp" "$SCRIPT_FILE"
        else
            FIRST_CODE=$(awk '
                NR == 1 { next }
                !/^[[:space:]]*$/ && !/^#/ { print NR; exit }
                END { print NR+1 }
            ' "$SCRIPT_FILE")
            awk -v line="$FIRST_CODE" -v ver="$INIT_VERSION" '
                NR == line && !done { print "readonly SCRIPT_VERSION=\"" ver "\""; done=1 }
                { print }
                END { if (!done) print "readonly SCRIPT_VERSION=\"" ver "\"" }
            ' "$SCRIPT_FILE" > "${SCRIPT_FILE}.tmp" && mv "${SCRIPT_FILE}.tmp" "$SCRIPT_FILE"
        fi
    fi

    echo "SUCCESS: Version $INIT_VERSION initialized in $SCRIPT_FILE"
    echo ""

    # Build next steps
    STEP=1
    if [[ "$AUTO_COMMIT" == true ]] && [[ "$SUGGEST_PIPEFAIL" == false ]]; then
        echo "Staging and committing initialization..."
        git add "$SCRIPT_FILE"
        git commit -m "chore: initialize version $INIT_VERSION — $CHANGE_DESC"
        echo ""
    fi
    echo "Next steps:"
    if [[ "$SUGGEST_PIPEFAIL" == true ]]; then
        echo "  $STEP. Add '$PIPEFAIL_LINE' before the 'readonly SCRIPT_VERSION=' line (enables safe scripting)"
        STEP=$((STEP + 1))
    fi
    if [[ "$AUTO_COMMIT" == false ]] || [[ "$SUGGEST_PIPEFAIL" == true ]]; then
        echo "  $STEP. Review: git diff $SCRIPT_FILE"
        STEP=$((STEP + 1))
        echo "  $STEP. Commit: git add $SCRIPT_FILE && git commit -m \"chore: initialize version $INIT_VERSION\""
        STEP=$((STEP + 1))
    fi
    echo "  $STEP. Tag:    git tag -a \"v$INIT_VERSION\" -m \"$CHANGE_DESC\""
    STEP=$((STEP + 1))
    echo "  $STEP. Push:   git push && git push --tags"
    exit 0
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

echo "New version: $NEW_VERSION"
echo "Change: $CHANGE_DESC"

# Update version in script file header (only lines with actual version numbers, not variables)
# Match VERSION: followed by any amount of whitespace and a version number, preserving alignment
sed -i.bak "s/^# VERSION:[[:space:]]*[0-9][0-9.]*$/# VERSION:     $NEW_VERSION/" "$SCRIPT_FILE"

# Update SCRIPT_VERSION constant (only lines with actual version numbers, not variables)
sed -i.bak "s/^readonly SCRIPT_VERSION=\"[0-9][0-9.]*\"/readonly SCRIPT_VERSION=\"$NEW_VERSION\"/" "$SCRIPT_FILE"

# Update CHANGELOG/History in script header (add new entry after the section header)
# Uses awk instead of sed: BSD sed on macOS does not support 0,/pattern/ address ranges
CHANGELOG_LINE="# $NEW_VERSION - $TODAY - $CHANGE_DESC"
awk -v newline="$CHANGELOG_LINE" '
    /^# CHANGELOG$/ || /^# History$/ { print; print newline; next }
    { print }
' "$SCRIPT_FILE" > "${SCRIPT_FILE}.tmp" && mv "${SCRIPT_FILE}.tmp" "$SCRIPT_FILE"

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
    # Build the new entry as a temp file (avoids sed/awk newline portability issues)
    ENTRY_FILE=$(mktemp)
    echo "## [$NEW_VERSION] - $TODAY" > "$ENTRY_FILE"
    echo "" >> "$ENTRY_FILE"
    case "$BUMP_TYPE" in
        major) echo "### Changed" >> "$ENTRY_FILE" ;;
        minor) echo "### Added" >> "$ENTRY_FILE" ;;
        patch) echo "### Fixed" >> "$ENTRY_FILE" ;;
    esac
    echo "- $CHANGE_DESC" >> "$ENTRY_FILE"
    echo "" >> "$ENTRY_FILE"

    # Insert before the first '## [' version heading
    if grep -q "^## \[" "$CHANGELOG_FILE"; then
        # Find the line number of the first version heading
        FIRST_VERSION_LINE=$(grep -n "^## \[" "$CHANGELOG_FILE" | head -1 | cut -d: -f1)
        # Split the file and reassemble with the new entry in between
        head -n $((FIRST_VERSION_LINE - 1)) "$CHANGELOG_FILE" > "${CHANGELOG_FILE}.tmp"
        cat "$ENTRY_FILE" >> "${CHANGELOG_FILE}.tmp"
        tail -n +"$FIRST_VERSION_LINE" "$CHANGELOG_FILE" >> "${CHANGELOG_FILE}.tmp"
        mv "${CHANGELOG_FILE}.tmp" "$CHANGELOG_FILE"
    else
        # No existing version entries — append to end
        echo "" >> "$CHANGELOG_FILE"
        cat "$ENTRY_FILE" >> "$CHANGELOG_FILE"
    fi
    rm -f "$ENTRY_FILE"
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
