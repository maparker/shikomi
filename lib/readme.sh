################################################################################
# LIB:         readme.sh
# DESCRIPTION: README generation functions for Shikomi
#
# FUNCTIONS:   generate_regular_readme(), generate_ea_readme()
#
# GLOBALS READ:
#   README_PATH, SCRIPT_NAME, SCRIPT_TEMPLATE, STATIC_README_ROWS[],
#   README_ROWS[], ONEPASSWORD_SECRETS[], BLOCK_VARIABLES[]
#
# GLOBALS WRITTEN: None (writes to $README_PATH)
################################################################################

function generate_ea_readme() {
    cat > "$README_PATH" << EOF
# $SCRIPT_NAME

**Type:** Jamf Pro Extension Attribute
**Version:** 1.0.0
**Author:** $(git config user.name || echo "First Last")
**Last Updated:** $(date +%Y-%m-%d)

## Description
This Extension Attribute reports inventory data to Jamf Pro.

## Purpose
Extension Attributes extend Jamf Pro's inventory data with custom information. This script:
- Runs during inventory updates
- Outputs data in \`<result>VALUE</result>\` format
- Should be silent except for the result output
- Typically collects read-only system information

## Static Configuration
$(if [ ${#STATIC_README_ROWS[@]} -gt 0 ]; then
    echo "| Variable | Type | Value | Description |"
    echo "|----------|------|-------|-------------|"
    printf '%s\n' "${STATIC_README_ROWS[@]}"
else
    echo "No static configuration variables defined."
fi)

## Jamf Pro Setup

### 1. Add Extension Attribute
1. Log into Jamf Pro
2. Navigate to **Settings** > **Computer Management** > **Extension Attributes**
3. Click **+ New**
4. Configure:
   - **Display Name:** $SCRIPT_NAME
   - **Description:** [Add description of what this reports]
   - **Data Type:** String (or Integer/Date as appropriate)
   - **Inventory Display:** Choose appropriate category
   - **Input Type:** Script
5. Paste the contents of \`$SCRIPT_NAME.sh\`
6. Click **Save**

### 2. Verify Collection
1. Run \`sudo jamf recon\` on a test Mac
2. Check computer inventory in Jamf Pro
3. Find the new attribute in the configured category

## Local Testing

Test the script locally to verify output format:

\`\`\`bash
./$SCRIPT_NAME.sh

# Expected output format:
# <result>VALUE_HERE</result>
\`\`\`

## Data Type Recommendations

| Data Type | Use When | Example Values |
|-----------|----------|----------------|
| **String** | Text values, version numbers, status | "1.2.3", "Installed", "Active" |
| **Integer** | Numeric counts, IDs, percentages | 42, 0, 100 |
| **Date** | Timestamps, dates | "2025-12-07", "2025-12-07 14:30:00" |

## Versioning
This script uses [Semantic Versioning](https://semver.org/). To bump the version:

\`\`\`bash
./bump-version.sh $SCRIPT_NAME.sh [major|minor|patch] "Description of changes"
\`\`\`
EOF
}

function generate_regular_readme() {
    cat > "$README_PATH" << EOF
# $SCRIPT_NAME

**Version:** 1.0.0
**Author:** $(git config user.name || echo "First Last")
**Last Updated:** $(date +%Y-%m-%d)

## Description
This script is designed for Jamf Pro deployment.

## Static Configuration
$(if [ ${#STATIC_README_ROWS[@]} -gt 0 ]; then
    echo "| Variable | Type | Value | Description |"
    echo "|----------|------|-------|-------------|"
    printf '%s\n' "${STATIC_README_ROWS[@]}"
else
    echo "No static configuration variables defined."
fi)

## Jamf Parameters
| Parameter | Label | Local Default / Env Var |
|-----------|-------|-------------------------|
$(if [ ${#README_ROWS[@]} -gt 0 ]; then
    printf '%s\n' "${README_ROWS[@]}"
else
    echo "| None | N/A | N/A |"
fi)

## Local Testing

### Prerequisites
$(if [ ${#ONEPASSWORD_SECRETS[@]} -gt 0 ]; then
    echo "This script uses **1Password** for secret management. Ensure you have:"
    echo "1. 1Password CLI installed: \`brew install 1password-cli\`"
    echo "2. Authenticated to 1Password: \`op account list\`"
    echo "3. Secrets stored in 1Password:"
    printf '   - %s\n' "${ONEPASSWORD_SECRETS[@]}"
    echo ""
fi)
$(if grep -q "LOCAL_" <<< "${BLOCK_VARIABLES[*]}" 2>/dev/null; then
    echo "For traditional local secrets, ensure \`~/.jamf_secrets\` exists with required variables."
    echo ""
fi)

### Run the script
\`\`\`bash
sudo ./$SCRIPT_NAME.sh
\`\`\`

### Testing 1Password Integration
$(if [ ${#ONEPASSWORD_SECRETS[@]} -gt 0 ]; then
    echo "Test secret retrieval:"
    echo "\`\`\`bash"
    printf 'op read "%s"\n' "${ONEPASSWORD_SECRETS[0]}"
    echo "\`\`\`"
    echo ""
fi)

## Versioning
This project uses [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes or incompatible API changes
- **MINOR**: New features, backward-compatible
- **PATCH**: Bug fixes, backward-compatible

To bump the version, use the provided version bump script:
\`\`\`bash
# Auto-detect script (typical usage)
./bump-version.sh [major|minor|patch] "Description of changes"

# Or specify script explicitly
./bump-version.sh $SCRIPT_NAME.sh [major|minor|patch] "Description"
\`\`\`
EOF
}
