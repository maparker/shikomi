# Pre-Commit Hook Reference

A side-by-side comparison of basic and enhanced pre-commit hooks and how to resolve common failures.

---

## Basic vs. Enhanced Hooks

| Hook | Basic | Enhanced | What It Catches |
|------|:-----:|:--------:|-----------------|
| **gitleaks** | Yes | Yes | Hardcoded secrets (API keys, tokens, passwords) |
| **shellcheck** | - | Yes | Shell script bugs, quoting issues, syntax problems |
| **trailing-whitespace** | - | Yes | Trailing spaces at end of lines |
| **end-of-file-fixer** | - | Yes | Missing newline at end of file |
| **check-yaml** | - | Yes | Invalid YAML syntax |
| **check-added-large-files** | - | Yes | Files larger than 1MB |
| **check-merge-conflict** | - | Yes | Leftover merge conflict markers |
| **detect-private-key** | - | Yes | SSH or GPG private keys |
| **Total checks** | **1** | **9** | |

### When to Use Each

- **Basic**: You want lightweight protection with minimal friction. Good for getting started.
- **Enhanced**: You want comprehensive quality checks. Recommended for team environments.

---

## What a Blocked Commit Looks Like

When a hook fails, the commit is blocked and you see output like this:

### Secret Detected (Gitleaks)

```
gitleaks...............................................................Failed
- hook id: gitleaks
- exit code: 1

Finding:    API_KEY="your-secret-key-here"
Secret:     your-secret-key-here
RuleID:     generic-api-key
Entropy:    3.8
File:       my_script.sh
Line:       42
Commit:     (staged)

        ⚠  1 secret(s) detected. Commit blocked.
```

**How to fix**: Remove the hardcoded secret. Use one of these instead:
- 1Password: `op read "op://Vault/Item/field"`
- File-based: Store in `~/.jamf_secrets` and reference with `${LOCAL_API_KEY:-${4}}`
- Jamf parameter: Use `${4}` directly

### ShellCheck Warning (Enhanced Only)

```
shellcheck..............................................................Failed
- hook id: shellcheck
- exit code: 1

In my_script.sh line 55:
  if [ $APP_NAME = "Slack" ]; then
       ^-------^ SC2086: Double quote to prevent globbing and word splitting.

Did you mean:
  if [ "$APP_NAME" = "Slack" ]; then
```

**How to fix**: Follow the suggestion. In this case, add double quotes around the variable:
```bash
# Before
if [ $APP_NAME = "Slack" ]; then

# After
if [ "$APP_NAME" = "Slack" ]; then
```

### Trailing Whitespace (Enhanced Only)

```
trim trailing whitespace................................................Failed
- hook id: trailing-whitespace
- exit code: 1
- files were modified by this hook

Fixing my_script.sh
```

**How to fix**: The hook auto-fixes this. Just re-stage and commit:
```bash
git add my_script.sh
git commit -m "your message"
```

### Large File Detected (Enhanced Only)

```
check for added large files.............................................Failed
- hook id: check-added-large-files
- exit code: 1

my_package.pkg (5.2 MB) exceeds the maximum file size of 1000 KB.
```

**How to fix**: Remove the file from staging and add it to `.gitignore`:
```bash
git reset HEAD my_package.pkg
echo "*.pkg" >> .gitignore
git add .gitignore
```

### Merge Conflict Markers (Enhanced Only)

```
check for merge conflicts...............................................Failed
- hook id: check-merge-conflict
- exit code: 1

my_script.sh:23: <<<<<<< HEAD
```

**How to fix**: Open the file and resolve the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`), then re-stage.

### Private Key Detected (Enhanced Only)

```
detect private key......................................................Failed
- hook id: detect-private-key
- exit code: 1

Private key found in: keys/deploy_key
```

**How to fix**: Remove the key file and add it to `.gitignore`. Never commit private keys to a repository.

---

## Managing Hooks

### Install Hooks (First Time)

```bash
pre-commit install
```

### Run Hooks Manually (Without Committing)

```bash
pre-commit run --all-files
```

### Run a Specific Hook

```bash
pre-commit run gitleaks --all-files
pre-commit run shellcheck --all-files
```

### Update Hook Versions

```bash
pre-commit autoupdate
```

### Switch from Basic to Enhanced

Replace your `.pre-commit-config.yaml` with the enhanced configuration, then reinstall:

```bash
pre-commit clean
pre-commit install
```

Or run `add_security_tools.sh` in your repo and choose enhanced when prompted.

---

## ShellCheck Common Fixes

| Code | Issue | Fix |
|------|-------|-----|
| SC2086 | Unquoted variable | Add double quotes: `"$VAR"` |
| SC2034 | Unused variable | Remove it or add `# shellcheck disable=SC2034` |
| SC2155 | Declare and assign separately | Split: `local var` then `var=$(command)` |
| SC2164 | Use `cd ... \|\| exit` | Add error handling: `cd "$DIR" \|\| exit 1` |
| SC2006 | Use `$(command)` not backticks | Replace `` `cmd` `` with `$(cmd)` |
| SC1091 | Cannot follow sourced file | Add `# shellcheck source=/dev/null` before source line |

Full reference: https://www.shellcheck.net/wiki/
