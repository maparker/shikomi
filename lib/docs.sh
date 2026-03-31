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

# copy_bump_version() — removed in favor of system-installed bump-version.
# bump-version is installed to PATH via install.sh and should not be copied
# into individual projects. See: bump-version --version

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
