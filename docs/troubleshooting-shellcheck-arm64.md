# Troubleshooting: Shellcheck "Bad CPU type in executable" on Apple Silicon

## The Error

```
shellcheck...............................................................Failed
- hook id: shellcheck
- exit code: 1

[Errno 86] Bad CPU type in executable: '/Users/<user>/.cache/pre-commit/<repoid>/py_env-python3.14/bin/shellcheck'
```

## What's Happening

Pre-commit caches hook environments under `~/.cache/pre-commit/`. When the shellcheck hook uses the `shellcheck-py` Python package (`repo: https://github.com/shellcheck-py/shellcheck-py`), pre-commit downloads a self-contained shellcheck binary into that cache.

On Apple Silicon Macs (arm64), the `shellcheck-py` package may have downloaded an x86_64 binary — either because:

- The package was installed under Rosetta, or
- An older version of `shellcheck-py` did not provide an arm64 wheel

The result is a cached x86_64 binary that fails with `[Errno 86] Bad CPU type` when run natively on arm64.

## Diagnosis

Run these two commands to confirm:

```bash
# Should say arm64
uname -m

# Should say x86_64 — this is the problem
file ~/.cache/pre-commit/<repoid>/py_env-python3.14/bin/shellcheck
```

You can find the correct `<repoid>` from the error message path.

## Fix

**Step 1 — Clear the stale pre-commit cache:**

```bash
pre-commit clean
```

This removes all cached environments under `~/.cache/pre-commit/`. They will be rebuilt correctly on the next run.

**Step 2 — Verify the system shellcheck is arm64:**

```bash
file $(which shellcheck)
# Expected: Mach-O 64-bit executable arm64
```

If shellcheck is missing or x86_64, reinstall it via Homebrew (which installs native arm64 binaries on Apple Silicon):

```bash
brew install shellcheck
```

**Step 3 — Run pre-commit again:**

```bash
pre-commit run --all-files
```

## Better Long-Term Fix: Use the System Shellcheck

The `shellcheck-py` approach (pre-commit downloads its own binary) is the source of this problem. Shikomi's templates instead configure shellcheck as a `local` hook with `language: system`, which delegates to whatever `shellcheck` is on `PATH`:

```yaml
- repo: local
  hooks:
    - id: shellcheck
      name: shellcheck
      language: system
      entry: shellcheck
      args: [--severity=warning]
      types: [shell]
```

**Advantages:**
- No binary download — no architecture mismatch possible
- Uses the Homebrew-managed version, which is always native arm64 on Apple Silicon
- Easier to update (just `brew upgrade shellcheck`)

If a project's `.pre-commit-config.yaml` still references `https://github.com/shellcheck-py/shellcheck-py`, replace that block with the `local` hook above.

## Quick Reference

| Symptom | Cause | Fix |
|---------|-------|-----|
| `[Errno 86] Bad CPU type` on shellcheck | Cached x86_64 binary on arm64 Mac | `pre-commit clean` |
| Shellcheck not found after clean | Not installed via Homebrew | `brew install shellcheck` |
| Error returns after next run | Config still uses `shellcheck-py` repo | Switch to `language: system` local hook |
