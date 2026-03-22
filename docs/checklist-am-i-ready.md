# Am I Ready? Pre-Flight Checklist

Use this checklist before starting your first Shikomi project to make sure everything is in place.

---

## Required Tools

- [ ] **Git** installed
  ```bash
  git --version
  ```

- [ ] **Shikomi** installed
  ```bash
  shikomi --version
  ```

- [ ] **pre-commit** installed
  ```bash
  pre-commit --version
  # Install: brew install pre-commit
  ```

---

## Recommended Tools

- [ ] **GitHub CLI** installed and authenticated
  ```bash
  gh auth status
  # Install: brew install gh
  # Authenticate: gh auth login
  ```

- [ ] **Gitleaks** installed (for local scanning outside of hooks)
  ```bash
  gitleaks version
  # Install: brew install gitleaks
  ```

---

## If Using 1Password for Secrets

- [ ] **1Password CLI** installed
  ```bash
  op --version
  # Install: brew install 1password-cli
  ```

- [ ] **1Password CLI** authenticated
  ```bash
  op account list
  # Setup: op account add
  ```

- [ ] **Vault and item** ready for your script's secrets

---

## If Deploying to Jamf Pro

- [ ] **Jamf Pro API Role** created with permissions:
  - [ ] Read Scripts
  - [ ] Create Scripts
  - [ ] Update Scripts

- [ ] **Jamf Pro API Client** created and assigned the role

- [ ] **Client ID** copied

- [ ] **Client Secret** copied (only shown once)

- [ ] **GitHub repository secrets** configured:
  - [ ] `JAMF_URL` (e.g. `https://yourinstance.jamfcloud.com`)
  - [ ] `JAMF_CLIENT_ID`
  - [ ] `JAMF_CLIENT_SECRET`

---

## Git Configuration

- [ ] **Name** configured
  ```bash
  git config user.name
  # Set: git config --global user.name "Your Name"
  ```

- [ ] **Email** configured
  ```bash
  git config user.email
  # Set: git config --global user.email "you@example.com"
  ```

---

## Optional but Recommended

- [ ] **Branch protection** enabled on `main` in GitHub
  - [ ] Require pull request before merging
  - [ ] Require at least 1 approval
  - [ ] Require status checks to pass

- [ ] **ShellCheck** installed locally (for IDE integration)
  ```bash
  shellcheck --version
  # Install: brew install shellcheck
  ```

---

## Quick Verification

Run this one-liner to check all required tools at once:

```bash
echo "--- Required ---" && \
git --version 2>/dev/null && echo "  Git: OK" || echo "  Git: MISSING" && \
shikomi --version 2>/dev/null && echo "  Shikomi: OK" || echo "  Shikomi: MISSING" && \
pre-commit --version 2>/dev/null && echo "  pre-commit: OK" || echo "  pre-commit: MISSING" && \
echo "" && echo "--- Optional ---" && \
gh --version 2>/dev/null | head -1 && echo "  GitHub CLI: OK" || echo "  GitHub CLI: not installed" && \
op --version 2>/dev/null && echo "  1Password CLI: OK" || echo "  1Password CLI: not installed" && \
gitleaks version 2>/dev/null && echo "  Gitleaks: OK" || echo "  Gitleaks: not installed"
```

---

## You Are Ready When

1. All **Required Tools** boxes are checked
2. At least **Git Configuration** is set
3. If deploying to Jamf Pro, all **Deploying to Jamf Pro** boxes are checked
4. You have run `shikomi --version` successfully

Go scaffold your first script:

```bash
shikomi my_first_script
```
