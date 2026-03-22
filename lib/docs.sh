################################################################################
# LIB:         docs.sh
# DESCRIPTION: CHANGELOG and bump-version copy functions for Shikomi
#
# FUNCTIONS:   copy_bump_version(), generate_changelog()
#
# GLOBALS READ:
#   SHIKOMI_DIR, BUMP_PATH, CHANGELOG_PATH, SCRIPT_NAME, SCRIPT_TEMPLATE,
#   SECRETS_USED
#
# GLOBALS WRITTEN: None (writes to $BUMP_PATH, $CHANGELOG_PATH)
################################################################################

function copy_bump_version() {
    # Locate the canonical bump-version.sh alongside shikomi
    local bump_version_source=""
    if [[ -f "$SHIKOMI_DIR/bump-version.sh" ]]; then
        bump_version_source="$SHIKOMI_DIR/bump-version.sh"
    elif [[ -f "$SHIKOMI_DIR/bump-version" ]]; then
        bump_version_source="$SHIKOMI_DIR/bump-version"
    else
        echo "Error: Cannot find bump-version.sh alongside shikomi"
        echo "Expected at: $SHIKOMI_DIR/bump-version.sh"
        exit 1
    fi

    # Write a clean usage header for the generated project
    cat > "$BUMP_PATH" << 'HEADER_EOF'
#!/bin/bash

################################################################################
# SCRIPT: bump-version.sh
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
HEADER_EOF

    # Append the portable body from the canonical bump-version.sh
    sed -n '/^# --- BEGIN PORTABLE ---$/,/^# --- END PORTABLE ---$/{
        /^# --- BEGIN PORTABLE ---$/d
        /^# --- END PORTABLE ---$/d
        p
    }' "$bump_version_source" >> "$BUMP_PATH"

    chmod +x "$BUMP_PATH"
}

function generate_changelog() {
    cat > "$CHANGELOG_PATH" << EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - $(date +%Y-%m-%d)

### Added
- Initial release of $SCRIPT_NAME
$(if [[ "$SCRIPT_TEMPLATE" == "ea" ]]; then
    echo "- Extension Attribute for Jamf Pro inventory reporting"
    echo "- Data collection logic"
    echo "- Proper <result> output formatting"
else
    echo "- Core functionality implemented"
    echo "- Jamf Pro parameter support"
    [ "$SECRETS_USED" = true ] && echo "- Secure secrets management"
fi)
EOF
}
