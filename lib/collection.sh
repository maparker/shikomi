################################################################################
# LIB:         collection.sh
# DESCRIPTION: Parameter/secret/static variable collection functions for Shikomi
#
# FUNCTIONS:   get_standard_vars_library(), apply_standard_var(),
#              apply_custom_var(), apply_jamf_parameter(),
#              apply_secret_parameter_1password(), apply_secret_parameter_local(),
#              apply_secret_parameter_manual()
#
# GLOBALS READ:
#   SCRIPT_NAME, BLOCK_HEADER[], BLOCK_VARIABLES[], BLOCK_LOGGING[],
#   README_ROWS[], STATIC_VARS[], STATIC_README_ROWS[],
#   SECRETS_USED, SECRET_REMINDERS[], ONEPASSWORD_SECRETS[]
#
# GLOBALS WRITTEN:
#   BLOCK_HEADER[], BLOCK_VARIABLES[], BLOCK_LOGGING[], README_ROWS[],
#   STATIC_VARS[], STATIC_README_ROWS[], SECRETS_USED,
#   SECRET_REMINDERS[], ONEPASSWORD_SECRETS[],
#   STANDARD_VARS_NAMES[], STANDARD_VARS_COMMANDS[],
#   STANDARD_VARS_DESCRIPTIONS[]  (indexed arrays, bash 3.2+ compatible)
################################################################################

function get_standard_vars_library() {
    # Populates indexed arrays with standard macOS variable definitions
    # Uses numeric indices (1-12) matching the menu selection numbers
    # Compatible with bash 3.2+ (no associative arrays required)

    STANDARD_VARS_NAMES=()
    STANDARD_VARS_NAMES[1]="SERIAL_NUMBER"
    STANDARD_VARS_NAMES[2]="LOGGED_IN_USER"
    STANDARD_VARS_NAMES[3]="COMPUTER_NAME"
    STANDARD_VARS_NAMES[4]="OS_VERSION"
    STANDARD_VARS_NAMES[5]="MODEL_IDENTIFIER"
    STANDARD_VARS_NAMES[6]="PRIMARY_IP"
    STANDARD_VARS_NAMES[7]="HOSTNAME"
    STANDARD_VARS_NAMES[8]="MAC_ADDRESS"
    STANDARD_VARS_NAMES[9]="CURRENT_USER_HOME"
    STANDARD_VARS_NAMES[10]="BOOT_VOLUME"
    STANDARD_VARS_NAMES[11]="TOTAL_RAM_GB"
    STANDARD_VARS_NAMES[12]="PROCESSOR_NAME"

    STANDARD_VARS_COMMANDS=()
    STANDARD_VARS_COMMANDS[1]='$(system_profiler SPHardwareDataType | awk '\''/Serial/ {print $4}'\'')'
    STANDARD_VARS_COMMANDS[2]='$(stat -f%Su /dev/console)'
    STANDARD_VARS_COMMANDS[3]='$(scutil --get ComputerName)'
    STANDARD_VARS_COMMANDS[4]='$(sw_vers -productVersion)'
    STANDARD_VARS_COMMANDS[5]='$(sysctl -n hw.model)'
    STANDARD_VARS_COMMANDS[6]='$(ipconfig getifaddr en0 || ipconfig getifaddr en1)'
    STANDARD_VARS_COMMANDS[7]='$(hostname)'
    STANDARD_VARS_COMMANDS[8]='$(ifconfig en0 | awk '\''/ether/ {print $2}'\'')'
    STANDARD_VARS_COMMANDS[9]='$(eval echo ~$(stat -f%Su /dev/console))'
    STANDARD_VARS_COMMANDS[10]='$(diskutil info / | awk '\''/Volume Name/ {print $3}'\'')'
    STANDARD_VARS_COMMANDS[11]='$(echo "scale=2; $(sysctl -n hw.memsize) / 1073741824" | bc)'
    STANDARD_VARS_COMMANDS[12]='$(sysctl -n machdep.cpu.brand_string)'

    STANDARD_VARS_DESCRIPTIONS=()
    STANDARD_VARS_DESCRIPTIONS[1]="Mac serial number"
    STANDARD_VARS_DESCRIPTIONS[2]="Currently logged in user"
    STANDARD_VARS_DESCRIPTIONS[3]="Computer name from System Preferences"
    STANDARD_VARS_DESCRIPTIONS[4]="macOS version number"
    STANDARD_VARS_DESCRIPTIONS[5]="Hardware model identifier"
    STANDARD_VARS_DESCRIPTIONS[6]="Primary network IP address"
    STANDARD_VARS_DESCRIPTIONS[7]="Network hostname"
    STANDARD_VARS_DESCRIPTIONS[8]="Primary MAC address"
    STANDARD_VARS_DESCRIPTIONS[9]="Home directory of logged in user"
    STANDARD_VARS_DESCRIPTIONS[10]="Name of boot volume"
    STANDARD_VARS_DESCRIPTIONS[11]="Total RAM in gigabytes"
    STANDARD_VARS_DESCRIPTIONS[12]="CPU processor name"
}

# Args: $1 = var number (1-12)
function apply_standard_var() {
    local num="$1"
    local var_name="${STANDARD_VARS_NAMES[$num]}"
    local var_cmd="${STANDARD_VARS_COMMANDS[$num]}"
    local var_desc="${STANDARD_VARS_DESCRIPTIONS[$num]}"

    STATIC_VARS+=("${var_name}=\"${var_cmd}\"  # ${var_desc}")
    STATIC_README_ROWS+=("| ${var_name} | Runtime | Dynamic | ${var_desc} |")
    echo "  Added: $var_name"
}

# Args: $1 = name, $2 = value, $3 = description
function apply_custom_var() {
    local static_name="$1"
    local static_value="$2"
    local static_desc="$3"

    STATIC_VARS+=("readonly ${static_name}=\"${static_value}\"  # ${static_desc}")
    STATIC_README_ROWS+=("| ${static_name} | Static | \`${static_value}\` | ${static_desc} |")
}

# Args: $1 = param_index (4-11), $2 = param_label, $3 = var_name, $4 = default_value
function apply_jamf_parameter() {
    local i="$1"
    local param_label="$2"
    local var_name="$3"
    local param_default="$4"

    BLOCK_HEADER+=("#   \$$i: $param_label")
    BLOCK_VARIABLES+=("${var_name}=\"\${${i}:-\"${param_default}\"}\"")
    BLOCK_LOGGING+=("log \"Config: $param_label [${var_name}]: \$$var_name\"")
    README_ROWS+=("| $i | $param_label | \`$param_default\` |")
}

# Args: $1 = param_index, $2 = param_label, $3 = var_name,
#        $4 = op_vault, $5 = op_item, $6 = op_field
function apply_secret_parameter_1password() {
    local i="$1"
    local param_label="$2"
    local var_name="$3"
    local op_vault="$4"
    local op_item="$5"
    local op_field="$6"
    local op_reference="op://${op_vault}/${op_item}/${op_field}"

    SECRETS_USED=true
    BLOCK_HEADER+=("#   $var_name (Jamf: \$$i)")

    # Generate 1Password-aware code
    BLOCK_VARIABLES+=("# Fetch from 1Password with fallback to Jamf parameter")
    BLOCK_VARIABLES+=("if command -v op &> /dev/null && op account list &> /dev/null 2>&1; then")
    BLOCK_VARIABLES+=("    ${var_name}=\"\$(op read '${op_reference}' 2>/dev/null || echo \"\${${i}}\")\"")
    BLOCK_VARIABLES+=("else")
    BLOCK_VARIABLES+=("    ${var_name}=\"\${${i}}\"  # Fallback to Jamf parameter")
    BLOCK_VARIABLES+=("fi")

    BLOCK_LOGGING+=("log \"Config: $param_label [${var_name}]: ******* (1Password)\"")
    README_ROWS+=("| $var_name | \$$i | \`${op_reference}\` (1Password) |")
    ONEPASSWORD_SECRETS+=("${op_reference}")
}

# Args: $1 = param_index, $2 = param_label, $3 = var_name
function apply_secret_parameter_local() {
    local i="$1"
    local param_label="$2"
    local var_name="$3"
    local secrets_file="$HOME/.jamf_secrets"
    local local_var_name="LOCAL_${var_name}"

    SECRETS_USED=true
    BLOCK_HEADER+=("#   $var_name (Jamf: \$$i)")
    BLOCK_VARIABLES+=("${var_name}=\"\${LOCAL_${var_name}:-\${${i}}}\"  # Secret: prefers local, falls back to Jamf \$$i")

    # Check if secrets file exists AND if the variable is defined in it
    if [[ -f "$secrets_file" ]] && grep -q "^${local_var_name}=" "$secrets_file"; then
        echo "   Found existing local secret: $local_var_name"
        BLOCK_LOGGING+=("log \"Config: $param_label [${var_name}]: ******* (Loaded from existing local secret)\"")
        README_ROWS+=("| $var_name | \$$i | \`${local_var_name}\` (Existing) |")
    else
        echo "   Local secret missing. You will need to add it later."
        BLOCK_LOGGING+=("log \"Config: $param_label [${var_name}]: ******* (Masked)\"")
        SECRET_REMINDERS+=("${local_var_name}=\"REPLACE_WITH_REAL_SECRET\"")
        README_ROWS+=("| $var_name | \$$i | \`${local_var_name}\` (Secret) |")
    fi
}

# Args: $1 = param_index, $2 = param_label, $3 = var_name
function apply_secret_parameter_manual() {
    local i="$1"
    local param_label="$2"
    local var_name="$3"

    SECRETS_USED=true
    BLOCK_HEADER+=("#   $var_name (Jamf: \$$i)")
    BLOCK_VARIABLES+=("${var_name}=\"\${${i}}\"  # TODO: Configure secret storage")
    BLOCK_LOGGING+=("log \"Config: $param_label [${var_name}]: ******* (Masked)\"")
    SECRET_REMINDERS+=("${var_name}: Configure secret storage manually")
    README_ROWS+=("| $var_name | \$$i | Manual configuration required |")
}
