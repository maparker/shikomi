# Changelog

All notable changes to Sabrage will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-07

### Added
- Initial release of Sabrage script generator
- Interactive wizard for MDM parameter collection ($4-$11)
- Standard macOS variables library (12 pre-configured variables)
- Static configuration variables support
- Secrets management via `~/.jamf_secrets`
- Semantic versioning with `bump_version.sh`
- Security tools integration via `add_security_tools.sh`
- Monorepo and micro-repo mode detection
- Automatic README.md and CHANGELOG.md generation
- Feature branch creation workflow
- GitHub CLI integration for repo creation
- Pre-commit hooks with Gitleaks secret scanning
- Optional GitHub Actions workflow generation
- Smart secret detection and masking in logs
- Version validation across script, README, and Git tags

### Core Components
- `script_creator_pro.sh` - Main script generator
- `bump_version.sh` - Semantic version management utility
- `add_security_tools.sh` - Security tooling setup

### Standard Variables
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

## Future Releases

### [1.1.0] - Planned
- MDM-agnostic mode (Intune, Kandji, Mosyle support)
- Enhanced secrets management with 1Password CLI
- Script template library
- VS Code snippets integration

### [2.0.0] - Future
- Windows PowerShell support
- Web-based UI
- Script testing framework
- Team collaboration features
