# GitOps Workflow Cheat Sheet

## The Flow

```
YOU (Local)                    GITHUB                         JAMF PRO
───────────                    ──────                         ────────
shikomi my_script
  ↓
Write your logic
  ↓
git commit ─────────┐
  Pre-commit hooks  │
  block bad code    │
  ↓                 │
git push ───────────┼────→ Pull Request opened
                    │        CI validates (ShellCheck,
                    │        version check, Gitleaks)
                    │          ↓
                    │      Review + Approve
                    │          ↓
                    └────→ Merge to main ──────────→ deploy-to-jamf.yml
                                                      ↓
                                                   Script created
                                                   or updated via API
```

---

## Key Commands

### Scaffold a New Script
```bash
# Interactive wizard
shikomi my_script_name

# Non-interactive with defaults
shikomi my_script_name --auto

# Non-interactive with Claude Code setup
shikomi my_script_name --auto --claude y --workflow y
```

### Implement and Test
```bash
# Edit your script
open my_script_name.sh

# Test locally
sudo ./my_script_name.sh
```

### Commit (Tier 1 Validation)
```bash
git add my_script_name.sh
git commit -m "feat: implement app installation"
# Pre-commit hooks run automatically
```

### Push and Create a Pull Request (Tier 2 Validation)
```bash
git push -u origin my-branch
gh pr create --title "Add my_script_name" --body "Description of changes"
```

### Bump Version
```bash
# Review changes manually before committing
bump-version patch "Fixed permission check"

# Or bump and commit in one step
bump-version patch "Fixed permission check" --commit

# Monorepo: specify the script explicitly
bump-version install_app.sh patch "Fixed permission check" --commit
```

### Merge and Deploy
```bash
# Merge via GitHub (after approval and CI pass)
gh pr merge
# deploy-to-jamf.yml triggers automatically
```

---

## Bump Types

| Type | When to Use | Example |
|------|-------------|---------|
| `patch` | Bug fixes | `bump-version patch "Fixed user detection"` |
| `minor` | New features | `bump-version minor "Added retry logic"` |
| `major` | Breaking changes | `bump-version major "Changed parameter order"` |

---

## Two Tiers of Protection

| Tier | Where | What Runs | Blocks |
|------|-------|-----------|--------|
| 1 | Your machine | Pre-commit hooks (Gitleaks, ShellCheck) | `git commit` |
| 2 | GitHub | CI workflow (ShellCheck, version check, Gitleaks) | PR merge |

---

## Common Pre-Commit Fixes

| Error | Fix |
|-------|-----|
| Gitleaks: secret detected | Move secret to 1Password or `~/.jamf_secrets` |
| ShellCheck: warning | Follow the suggestion in the output (e.g. quote variables) |
| Trailing whitespace | Remove trailing spaces from the flagged lines |
| Large file detected | Remove the file or add it to `.gitignore` |
