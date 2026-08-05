# Changelog

All notable changes to Shikomi will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.3.0] - 2026-08-05

### Added
- Swap gitleaks for betterleaks (unmaintained upstream) in pre-commit hooks and CI workflow

## [1.4.0] - 2026-07-30 (bump-version.sh)

### Added
- **bump-version.sh** (v1.4.0): Recognize zsh-style scriptVersion= declarations (with or without readonly) alongside bash readonly SCRIPT_VERSION=; clarify that init falls back to header-anchor when no pipefail line exists; disambiguate CHANGELOG heading with script name when a version number collides with an existing entry

## [1.3.2] - 2026-07-08

### Fixed
- Fix exec bit loss in tmp-file rewrites of SCRIPT_FILE (regression from v1.2.3's sed→awk swap)

## [1.3.1] - 2026-07-08

### Fixed
- Limit auto-commit to pathspec of intended files, not entire index

## [2.1.3] - 2026-07-08

### Fixed
- Updated banner text and print_shikomi_banner helper

## [1.2.4] - 2026-06-19

### Fixed
- Add --help/-h flag support

## [2.1.2] - 2026-06-19

### Fixed
- Clarified shellcheck disable comments to instruct developers to remove them once the variable is used

## [2.1.1] - 2026-06-19 (shikomi.sh)

### Fixed
- **shikomi.sh** (v2.1.1): Add SC2034 suppression for scaffolded variables and end-of-wizard note

## [1.2.2] - 2026-04-29

### Fixed
- Add History block support for EA scripts alongside CHANGELOG

## [2.1.1] - 2026-04-01 (bump-version.sh)

### Fixed
- **bump-version.sh** (v1.2.1): Auto-detect now selects the **most recently modified** versioned script instead of the first one alphabetically. When multiple `.sh` files with a `SCRIPT_VERSION` constant exist, the one you edited most recently is chosen — matching the intent of "bump the script I'm working on." A warning still lists all candidates and now indicates which was selected and why.

## [2.1.0] - 2026-03-27

### Added
- Removed per-repo bump-version.sh scaffolding; bump-version is now used exclusively as a system-installed command via install.sh

## [1.2.1] - 2026-03-27

### Fixed
- Removed per-repo bump-version.sh scaffolding in favor of system-installed bump-version

## [2.0.0] - 2026-03-23

### Added
- **Non-interactive CLI mode** (`--auto` flag) — all prompts can be skipped with sensible defaults
- 13 CLI flags for controlling every interactive prompt: `--template`, `--ea-suffix`, `--scaffolding`, `--params-file`, `--no-params`, `--static-vars`, `--branch`, `--hooks`, `--workflow`, `--deploy-workflow`, `--github`, `--claude`
- **`--params-file`** — load Jamf parameters from a JSON file, parsed with `plutil` (stock macOS, no python3/jq dependency)
- **Claude Code scaffolding** (`--claude y`) — generates project-aware `CLAUDE.md` and initialized `SESSION_DIARY.md`
  - `CLAUDE.md` includes: shell conventions, versioning rules, secret management method, security rules, EA guidelines (if applicable), session diary instruction
  - In monorepo mode, files are generated at repo root only if they don't already exist
- New library file: `lib/claude-setup.sh` — `generate_claude_md()` and `init_session_diary()` functions
- `parse_params_file()` function in `lib/collection.sh` for non-interactive parameter ingestion
- `show_usage()` function with comprehensive flag documentation and examples
- **Monorepo deploy workflow** — `generate_monorepo_deploy_workflow()` auto-detects changed versioned scripts via `git diff`, deploys each to Jamf Pro, posts summary table
- **Monorepo validation workflow** — `generate_monorepo_validate_workflow()` runs ShellCheck and Gitleaks on changed scripts only
- Monorepo mode in `shikomi.sh` now offers workflow generation (previously only new-repo mode did)
- `add_security_tools.sh` auto-detects monorepo (multiple versioned scripts) and generates monorepo workflow

### Changed
- Argument parsing rewritten from simple if/elif to `while/shift` loop supporting positional script name + flags
- Each interactive prompt now checks for its corresponding flag before falling back to interactive input
- Individual flags work without `--auto` (e.g., `shikomi my_script --template ea` skips only the template prompt)
- `stage_monorepo_files()` in `lib/git-setup.sh` now stages `CLAUDE.md` and `SESSION_DIARY.md` when generated
- Bumped version to 2.0.0

## [1.9.0] - 2026-03-22

### Changed
- Extracted monolithic `shikomi.sh` into modular `lib/` structure with 6 sourced library files
  - `lib/templates.sh` — script template generation (`generate_regular_script()`, `generate_ea_script()`)
  - `lib/readme.sh` — README generation (`generate_regular_readme()`, `generate_ea_readme()`)
  - `lib/docs.sh` — CHANGELOG and bump-version copy (`copy_bump_version()`, `generate_changelog()`)
  - `lib/workflows.sh` — GitHub Actions workflow generation (`generate_validate_workflow()`, `generate_deploy_workflow()`)
  - `lib/git-setup.sh` — Git init, branching, pre-commit, and GitHub setup
  - `lib/collection.sh` — parameter, secret, and static variable collection functions
- `shikomi.sh` is now a thin orchestrator (~570 lines) that sources `lib/*.sh` and handles interactive prompts
- `SHIKOMI_LIB` resolves from repo directory, `~/.local/lib/shikomi/lib`, or `/usr/local/lib/shikomi/lib`
- `install.sh` (v1.2.0) now copies `lib/` directory during install, removes on uninstall, refreshes on update

## [1.8.0] - 2026-03-22

### Added
- Optional GitHub Actions workflow to deploy scripts to Jamf Pro on merge via the Jamf Pro API
- Workflow authenticates via OAuth, detects create vs. update, and posts deployment summary
- Added `--commit` flag to `bump-version` for automatic staging and committing of version bumps
- Deploy workflow prompt is only offered after accepting PR validation workflow
- Bumped `bump-version.sh` to v1.2.0

### Changed
- Replaced embedded bump-version heredoc with marker-based extraction from the canonical `bump-version.sh` (single source of truth)
- Added `SHIKOMI_DIR` resolution so shikomi can locate sibling files at runtime
- `bump-version` now resolves README and CHANGELOG paths automatically (supports both `README.md` and `{script_name}_README.md` conventions)
- `bump-version` gracefully skips README and CHANGELOG updates when those files don't exist (monorepo without scaffolding)
- `--commit` flag now stages only the files bump-version touched, allowing other uncommitted changes to coexist
- Added explanatory comment to generated secrets source block clarifying it is for local development only

### Removed
- Removed bundled project-specific workflows (jamf-auto-patch.yml, validate-script.yml) that did not belong in the framework repo

## [1.7.1] - 2026-03-10

### Fixed
- Fixed logging functions to output to stderr - prevents stdout pollution in command substitution
- Fixed LOG_FILE usage in generated scripts - stderr now tees to log file via `exec`
- Fixed broken `$LOCAL_` variable expansion in README generation for traditional secrets
- Fixed CHANGELOG.md insertion logic to use pattern matching instead of fragile line numbers
- Fixed hardcoded `@prizepicks.com` email fallback in regular script template
- Added input validation for script names to prevent path injection
- Moved monorepo dirty-repo check before file creation to avoid orphaned files
- Deduplicated pre-commit config blocks in add_security_tools.sh
- Fixed VERSION header whitespace alignment for consistent sed matching

## [1.7.0] - 2026-01-25

### Added
- Multi-template support for different script types
- Extension Attribute (EA) template for Jamf Pro inventory reporting
- Automatic `_ea` suffix suggestion for EA scripts
- EA-specific README with Jamf Pro setup instructions
- Template selection prompt at script generation start

### Changed
- Refactored script generation to support multiple templates
- Conditional parameter collection based on template type
- Enhanced final summary with template-specific guidance

## [1.6.0] - 2026-01-25

### Added
- Added 1Password integration for secret storage with interactive configuration during script generation

## [1.5.4] - 2026-01-19

### Fixed
- Updated bump-version.sh to only modify actual version numbers, not template variables

## [1.5.3] - 2026-01-19

### Fixed
- Fixed version template to prevent generated scripts from inheriting shikomi's version number

## [1.5.2] - 2026-01-19

### Fixed
- Updated the created gitignore file to better prevent committing pkg files.

## [1.5.1] - 2026-01-18

### Added
- **shikomi.sh**: Enhanced logging functions in generated scripts (`log()`, `log_warn()`, `log_error()`, `log_success()`)
- **README.md**: Comprehensive "Built-in Logging Functions" documentation section with usage examples
- **README.md**: Log filtering and stderr redirection examples

### Changed
- **shikomi.sh**: Version bumped from 1.5.0 to 1.5.1
- **shikomi.sh**: Generated scripts now include INFO severity level in standard log() function
- **shikomi.sh**: Error and warning functions now output to stderr for proper stream separation

---

## [1.5.0] - 2026-01-18

### Added
- **bump-version.sh**: Added munkipkg integration for automatic package version updates
- **bump-version.sh**: Support for updating `build-info.json` and `build-info.plist` files
- **bump-version.sh**: Searches multiple common locations (root, pkg/, build/) for munkipkg build-info files
- **bump-version.sh**: Automatic version synchronization between scripts and macOS installer packages
- **shikomi.sh**: Updated generated .gitignore to be munkipkg-friendly (allows `pkg/` directory, ignores `build/*.pkg`)

### Changed
- **bump-version.sh**: Version bumped from 1.0.1 to 1.1.0
- **shikomi.sh**: Version bumped from 1.4.3 to 1.5.0
- **shikomi.sh**: Now generates bump-version.sh with munkipkg support built-in
- **shikomi.sh**: Improved .gitignore template to support munkipkg workflows

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

## [1.4.0] - 2026-01-08 (shikomi.sh)

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
