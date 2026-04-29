# shellcheck shell=bash
################################################################################
# LIB:         templates.sh
# DESCRIPTION: Script template generation functions for Shikomi
#
# FUNCTIONS:   generate_regular_script(), generate_ea_script()
#
# GLOBALS READ:
#   SCRIPT_PATH, SCRIPT_NAME, INITIAL_VERSION, INITIAL_DATE,
#   BLOCK_HEADER[], BLOCK_VARIABLES[], BLOCK_LOGGING[], STATIC_VARS[],
#   SECRETS_USED
#
# GLOBALS WRITTEN: None (writes to $SCRIPT_PATH)
################################################################################

function generate_ea_script() {
    cat > "$SCRIPT_PATH" << EOF
#!/bin/bash

##################################################################
# SCRIPT:         ${SCRIPT_NAME}.sh
# VERSION:        ${INITIAL_VERSION}
# DESCRIPTION:    Extension Attribute for Jamf Pro inventory reporting
#
# AUTHOR:         $(git config user.name || echo "First Last")
# EMAIL:          $(git config user.email || echo "first.last@example.com")
##################################################################
#
# History
# ${INITIAL_VERSION} - ${INITIAL_DATE} - Initial release
#
##################################################################

# --- Script Metadata ---
readonly SCRIPT_VERSION="${INITIAL_VERSION}"

# --- Static Configuration ---
$(printf '%s\n' "${STATIC_VARS[@]}")

# --- Data Collection Logic ---
# TODO: Add your data collection logic here
# Example with error handling:
# RESULT=\$(command_to_get_data 2>/dev/null)
# RESULT="\${RESULT:-Not Available}"  # Fallback if empty or command fails

# --- Output Result ---
# Extension Attributes MUST output in this format:
RESULT="Not Configured"

echo "<result>\${RESULT}</result>"
exit 0
EOF
    chmod +x "$SCRIPT_PATH"
}

function generate_regular_script() {
    cat > "$SCRIPT_PATH" << EOF
#!/bin/bash

################################################################################
# SCRIPT:      ${SCRIPT_NAME}.sh
# VERSION:     ${INITIAL_VERSION}
# AUTHOR:      $(git config user.name || echo "First Last")
# EMAIL:       $(git config user.email || echo "first.last@example.com")
# DATE:        ${INITIAL_DATE}
# Description: Fancy script that makes something cool happen on a Mac.
#
################################################################################
# PARAMETERS:
$(printf '%s\n' "${BLOCK_HEADER[@]}")
################################################################################
# CHANGELOG
# ${INITIAL_VERSION} - ${INITIAL_DATE} - Initial release
################################################################################

# --- Script Metadata ---
readonly SCRIPT_VERSION="${INITIAL_VERSION}"
readonly SCRIPT_NAME="${SCRIPT_NAME}"

$(if [ "$SECRETS_USED" = true ] && ! printf '%s\n' "${BLOCK_VARIABLES[@]}" | grep -q "op read"; then
    echo '# --- Local Development Secrets ---'
    echo '# This block is for local testing only. On managed endpoints (via Jamf Pro),'
    echo '# this file will not exist and secrets are delivered through parameters ($4-$11).'
    echo 'if [[ -f "$HOME/.jamf_secrets" ]]; then'
    echo '    source "$HOME/.jamf_secrets"'
    echo 'fi'
elif [ "$SECRETS_USED" = true ]; then
    echo '# --- Local Development Secrets (fallback for non-1Password secrets) ---'
    echo '# This block is for local testing only. On managed endpoints (via Jamf Pro),'
    echo '# this file will not exist and secrets are delivered through parameters ($4-$11).'
    echo 'if [[ -f "$HOME/.jamf_secrets" ]]; then'
    echo '    source "$HOME/.jamf_secrets"'
    echo 'fi'
fi)

# --- Static Configuration ---
$(printf '%s\n' "${STATIC_VARS[@]}")

# --- Configuration (Jamf Parameters) ---
$(printf '%s\n' "${BLOCK_VARIABLES[@]}")

# --- Logging Setup ---
LOG_FILE="/var/log/${SCRIPT_NAME}.log"
function log()         { local msg; msg="[\$(date '+%Y-%m-%d %H:%M:%S')] INFO: \$*";    echo "\$msg" >&2; echo "\$msg" >> "\$LOG_FILE" 2>/dev/null; }
function log_warn()    { local msg; msg="[\$(date '+%Y-%m-%d %H:%M:%S')] WARN: \$*";    echo "\$msg" >&2; echo "\$msg" >> "\$LOG_FILE" 2>/dev/null; }
function log_error()   { local msg; msg="[\$(date '+%Y-%m-%d %H:%M:%S')] ERROR: \$*";   echo "\$msg" >&2; echo "\$msg" >> "\$LOG_FILE" 2>/dev/null; }
function log_success() { local msg; msg="[\$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: \$*"; echo "\$msg" >&2; echo "\$msg" >> "\$LOG_FILE" 2>/dev/null; }

# --- Main Logic ---
log "Starting \$SCRIPT_NAME v\$SCRIPT_VERSION..."
$(printf '%s\n' "${BLOCK_LOGGING[@]}")

log "----------------------------------------"
# TODO: Add logic here
log "\$SCRIPT_NAME completed successfully"
exit 0
EOF
    chmod +x "$SCRIPT_PATH"
}
