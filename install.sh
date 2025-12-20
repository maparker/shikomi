#!/bin/bash

################################################################################
# SCRIPT:      install.sh
# VERSION:     1.0.0
# AUTHOR:      Matt Parker
# DATE:        2025-12-20
# DESCRIPTION: Installation script for Shikomi CLI tools
#
# USAGE: ./install.sh [--user|--system|--uninstall]
################################################################################

set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="install"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Installation files (source_file:target_name pairs)
TOOLS=(
    "shikomi.sh:shikomi"
    "bump-version.sh:bump-version"
)

# Installation directories
USER_BIN_DIR="$HOME/.local/bin"
SYSTEM_BIN_DIR="/usr/local/bin"

################################################################################
# Functions
################################################################################

function print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}   Shikomi CLI Installation${NC}"
    echo -e "${BLUE}   Version: $SCRIPT_VERSION${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
}

function log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

function log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

function log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $*"
}

function log_error() {
    echo -e "${RED}[✗]${NC} $*"
}

function show_help() {
    cat << EOF
Shikomi Installation Script v$SCRIPT_VERSION

USAGE:
    ./install.sh [OPTIONS]

OPTIONS:
    --user          Install to ~/.local/bin (default, no sudo required)
    --system        Install to /usr/local/bin (requires sudo)
    --uninstall     Remove installed tools
    --help, -h      Show this help message
    --version, -v   Show version information

DESCRIPTION:
    This script installs Shikomi CLI tools to your system PATH.

    Tools installed:
    - shikomi        : Main script generator
    - bump-version   : Version management utility

    After installation, you can run these commands from anywhere:
        shikomi my_script
        bump-version my_script.sh patch "Fixed bug"

EXAMPLES:
    # User installation (recommended, no sudo needed)
    ./install.sh
    ./install.sh --user

    # System-wide installation (requires sudo)
    sudo ./install.sh --system

    # Uninstall
    ./install.sh --uninstall

EOF
}

function verify_source_files() {
    local missing=0
    for tool_pair in "${TOOLS[@]}"; do
        local source_file="${tool_pair%%:*}"
        if [[ ! -f "$source_file" ]]; then
            log_error "Source file not found: $source_file"
            missing=1
        fi
    done

    if [[ $missing -eq 1 ]]; then
        log_error "Please run this script from the shikomi repository root directory"
        exit 1
    fi
}

function install_tools() {
    local install_dir="$1"
    local needs_sudo="$2"

    log_info "Installing to: $install_dir"

    # Create installation directory if needed
    if [[ ! -d "$install_dir" ]]; then
        if [[ "$needs_sudo" == "true" ]]; then
            sudo mkdir -p "$install_dir"
            log_success "Created directory: $install_dir"
        else
            mkdir -p "$install_dir"
            log_success "Created directory: $install_dir"
        fi
    fi

    # Install each tool
    for tool_pair in "${TOOLS[@]}"; do
        local source_file="${tool_pair%%:*}"
        local target_name="${tool_pair##*:}"
        local target_path="$install_dir/$target_name"

        log_info "Installing $target_name..."

        if [[ "$needs_sudo" == "true" ]]; then
            sudo cp "$source_file" "$target_path"
            sudo chmod +x "$target_path"
        else
            cp "$source_file" "$target_path"
            chmod +x "$target_path"
        fi

        log_success "Installed: $target_path"
    done

    echo ""
    log_success "Installation complete!"
    echo ""

    # Check if install_dir is in PATH
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        log_warning "Directory $install_dir is not in your PATH"
        echo ""
        echo "Add this line to your shell configuration file:"
        echo ""
        if [[ "$SHELL" == *"zsh"* ]]; then
            echo -e "${YELLOW}    echo 'export PATH=\"\$PATH:$install_dir\"' >> ~/.zshrc${NC}"
            echo -e "${YELLOW}    source ~/.zshrc${NC}"
        else
            echo -e "${YELLOW}    echo 'export PATH=\"\$PATH:$install_dir\"' >> ~/.bashrc${NC}"
            echo -e "${YELLOW}    source ~/.bashrc${NC}"
        fi
        echo ""
    else
        log_success "Installation directory is already in PATH"
        echo ""
        echo "You can now run these commands from anywhere:"
        for tool_pair in "${TOOLS[@]}"; do
            local target_name="${tool_pair##*:}"
            echo "  - $target_name"
        done
        echo ""
    fi
}

function uninstall_tools() {
    local found=0

    log_info "Searching for installed tools..."
    echo ""

    # Check both installation directories
    for install_dir in "$USER_BIN_DIR" "$SYSTEM_BIN_DIR"; do
        for tool_pair in "${TOOLS[@]}"; do
            local target_name="${tool_pair##*:}"
            local target_path="$install_dir/$target_name"

            if [[ -f "$target_path" ]]; then
                found=1
                log_info "Found: $target_path"

                if [[ "$install_dir" == "$SYSTEM_BIN_DIR" ]]; then
                    sudo rm -f "$target_path"
                else
                    rm -f "$target_path"
                fi

                log_success "Removed: $target_path"
            fi
        done
    done

    echo ""
    if [[ $found -eq 1 ]]; then
        log_success "Uninstallation complete!"
    else
        log_warning "No installed tools found"
    fi
}

################################################################################
# Main
################################################################################

# Parse arguments
MODE="user"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)
            MODE="user"
            shift
            ;;
        --system)
            MODE="system"
            shift
            ;;
        --uninstall)
            MODE="uninstall"
            shift
            ;;
        --version|-v)
            echo "install.sh v$SCRIPT_VERSION"
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
done

print_header

# Handle uninstall
if [[ "$MODE" == "uninstall" ]]; then
    uninstall_tools
    exit 0
fi

# Verify source files exist
verify_source_files

# Install based on mode
case "$MODE" in
    user)
        install_tools "$USER_BIN_DIR" "false"
        ;;
    system)
        if [[ $EUID -ne 0 ]]; then
            log_error "System installation requires sudo"
            log_info "Please run: sudo ./install.sh --system"
            exit 1
        fi
        install_tools "$SYSTEM_BIN_DIR" "true"
        ;;
esac

exit 0
