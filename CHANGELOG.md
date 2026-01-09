# Changelog

All notable changes to Shikomi will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.4.3] - 2026-01-09

### Fixed
- Fixed secrets variable


## [1.4.2] - 2026-01-08

### Fixed
- **shikomi.sh**: Corrected new script template version to start at `1.0.0` instead of inheriting shikomi's version (`1.4.1`)
- **shikomi.sh**: Fixed CHANGELOG template to only include initial release entry for new scripts
- **shikomi.sh**: Fixed `SCRIPT_VERSION` constant in generated scripts to match version header

---

## [1.4.1] - 2026-01-08

### Changed
- **shikomi.sh**: Updated default shebang from `#!/bin/zsh --no-rcs` to `#!/bin/bash` for better compatibility
- Generated scripts now use bash by default instead of zsh

---

## [1.4.0] - 2026-01-08

### Fixed
- **shikomi.sh**: Initial attempt to fix versioning for new script creation (incomplete - fully resolved in 1.4.2)

---

## [1.3.0] - 2026-01-08

### Added
- **shikomi.sh**: Interactive prompt for choosing pre-commit hook level during project creation
  - Basic mode: Gitleaks only (secrets scanning)
  - Enhanced mode: 9 comprehensive checks (secrets, ShellCheck, file quality)
- **shikomi.sh**: Enhanced hooks include ShellCheck linting, trailing whitespace removal, YAML validation, merge conflict detection, and more
- **README.md**: Documentation for two-tier pre-commit hook system
- **README.md**: Updated example session to show hook level selection

### Changed
- **shikomi.sh**: Improved pre-commit installation messages with clear feedback
- **shikomi.sh**: Better error messaging when pre-commit is not installed

---

## [1.2.0] - 2025-12-20

### Changed - BREAKING
- **shikomi.sh**: Now generates `bump-version.sh` (hyphenated) instead of `bump_version.sh` (underscore)
- Standardized naming convention across all generated projects
- All scripts now use modern CLI hyphenated naming throughout the ecosystem

### Added
- **bump-version.sh**: Intelligent header detection during `init` command
- **bump-version.sh**: Automatic metadata extraction from existing headers (Description, Author, Usage)
- **bump-version.sh**: Case-insensitive field matching for header parsing
- **bump-version.sh**: Clean header replacement with zero duplication

### Documentation
- Updated SHIKOMI_EXPLANATION.md with comprehensive v1.2.0 changes
- Clarified naming conventions across all documentation
- Fixed legacy "Sabrage" references in README.md
- Added "Recent Updates" section to EXPLANATION file

---

## [1.1.0] - 2025-12-20

### Added
- **install.sh**: New installation script for system-wide CLI deployment
- **install.sh**: User installation mode (`~/.local/bin`) - no sudo required
- **install.sh**: System installation mode (`/usr/local/bin`) - requires sudo
- **install.sh**: `--update` flag for easy updates via git pull
- **install.sh**: `--uninstall` flag for clean removal
- **install.sh**: PATH detection and setup guidance
- **bump-version.sh**: `init` command to bootstrap versioning for unversioned scripts
- **bump-version.sh**: Sets initial version to 1.0.0 with proper header structure

### Changed
- Renamed standalone `bump_version.sh` to `bump-version.sh` for modern CLI conventions
- Scripts can now be called as `shikomi` and `bump-version` from anywhere (when installed)
- **shikomi.sh**: Updated to support install.sh integration

### Documentation
- Added installation instructions to README.md
- Documented update workflow for both git and ZIP downloads

---

## [1.0.0] - 2025-12-07

### Added - Initial Release
- **shikomi.sh**: Interactive script generator for macOS/MDM automation
- Interactive wizard for MDM parameter collection (supports Jamf Pro $4-$11)
- Standard macOS variables library (12 pre-configured system variables)
- Static configuration variables support
- Secrets management via `~/.jamf_secrets`
- Semantic versioning with `bump-version.sh` utility
- **add_security_tools.sh**: Security tools integration (Gitleaks, pre-commit hooks)
- Monorepo and micro-repo mode detection
- Automatic README.md and CHANGELOG.md generation
- Feature branch creation workflow
- GitHub CLI integration for repo creation
- Pre-commit hooks with Gitleaks secret scanning
- Optional GitHub Actions workflow generation
- Smart secret detection and masking in logs
- Version validation across script, README, and Git tags

### Core Components
- `shikomi.sh` (v1.0.0) - Main script generator
- `bump-version.sh` (v1.0.0) - Semantic version management utility
- `add_security_tools.sh` (v1.0.0) - Security tooling setup

### Standard Variables Library
Includes 12 macOS system variables:
1. Serial Number
2. Logged In User
3. Computer Name
4. OS Version
5. Model Identifier
6. Primary IP Address
7. Hostname
8. MAC Address
9. Current User Home Directory
10. Boot Volume Name
11. Total RAM (GB)
12. Processor Name

---

## Future Roadmap

### Potential Future Enhancements
- MDM-agnostic mode (Intune, Kandji, Mosyle support)
- Enhanced secrets management with 1Password CLI
- Script template library
- VS Code snippets integration
- Homebrew formula for easier installation
- Windows PowerShell support
- Web-based UI
- Script testing framework
- Team collaboration features
