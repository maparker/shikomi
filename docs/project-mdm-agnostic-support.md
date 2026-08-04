# Project: MDM-Agnostic Support

## Overview

Shikomi currently generates scripts against a single implicit target: Jamf Pro. Parameter handling assumes Jamf's `$4`-`$11` positional script-parameter convention, Extension Attribute output assumes Jamf's `<result>VALUE</result>` format, and the optional deploy workflow calls the Jamf Pro REST API directly. This is already called out as a roadmap item in the shikomi README ("MDM-Agnostic Mode — Intune, Kandji, Mosyle").

This document lays out where the Jamf coupling actually lives in the codebase, a provider-based design to generalize it without breaking existing Jamf users, a suggested rollout order, and a deeper look at Fleet as a candidate provider given its GitOps-first design.

**Repository:** `shikomi`
**Current version:** shikomi v2.1.3 / bump-version v1.3.2
**Owner:** Matthew Parker

---

## Where Jamf is coupled into the codebase

| Coupling point | Where | Difficulty to abstract |
|---|---|---|
| Parameter delivery (`$4`-`$11` positional) | `lib/collection.sh` | Hard — every MDM injects config differently |
| EA/inventory output format (`<result>`) | `lib/templates.sh` | Medium — each MDM has its own reporting contract |
| Deploy workflow (Jamf Pro REST API calls) | `lib/workflows.sh` | Medium — API shape differs per vendor |
| Terminology/docs (`.jamf_secrets`, `JAMF_NAME:` header, CLAUDE.md text) | `lib/claude-setup.sh`, `lib/docs.sh` | Easy — mostly string swaps |

---

## Proposed design: a provider abstraction

1. **Add `--mdm jamf|kandji|intune|mosyle|fleet|generic`**, defaulting to `jamf` so nothing changes for existing users. Store the choice in a `.shikomirc` at repo root so monorepo users don't have to re-specify it per script.

2. **Split the Jamf-specific logic out of `lib/collection.sh`, `lib/templates.sh`, and `lib/workflows.sh` into provider files** — `lib/providers/jamf.sh`, `lib/providers/kandji.sh`, etc. — each implementing the same function names, dispatched on `$MDM_PROVIDER`.

3. **Reuse the existing output contract instead of inventing a new one.** Every parameter-collection function already funnels into the same four shared arrays regardless of source (interactive wizard or `--params-file`): `BLOCK_HEADER[]`, `BLOCK_VARIABLES[]`, `BLOCK_LOGGING[]`, `README_ROWS[]` (plus the secret side-channels `SECRETS_USED`, `SECRET_REMINDERS[]`, `ONEPASSWORD_SECRETS[]`). `lib/templates.sh` only consumes those arrays to assemble the final script — it doesn't know or care how they were populated.

   So the real move is: keep those four arrays as the interface, and let each provider own the input side (`apply_jamf_parameter`, `apply_secret_parameter_1password`, `parse_params_file`) with its own logic for producing them. Jamf's provider fills `$i` positionally; a hypothetical Intune provider fills from an env var or a `defaults read` against a pushed plist. Nothing downstream changes.

4. **Don't let providers duplicate the secret-wrapping logic.** Diffing `apply_jamf_parameter` against `apply_secret_parameter_1password/local/manual` (`lib/collection.sh:95-172`), the only Jamf-specific pieces are the raw-value expression (`${${i}}`) and the comment text (`Jamf: $i`). The 1Password `op read`-with-fallback wrapping, local-secrets-file lookup, and masked-logging line are identical shape regardless of MDM. Split it:
   - **Provider owns:** how to get a parameter's raw value (`${4}` for Jamf/Kandji; an env var or `defaults read` against a pushed plist for Intune; `$FLEET_SECRET_*` token substitution for Fleet) and how to label it in comments/README.
   - **Shared code owns:** the secret-wrapping logic (1Password/local-file/manual), parameterized on that raw-value expression instead of hardcoding `$i`. Written once, not once per provider.

5. **`parse_params_file()`'s JSON schema hardcodes `index` as a required field** (`lib/collection.sh:218` — the parameter is skipped if `index` or `label` is missing). `index` is meaningless for a provider with no positional params. Keep the plutil JSON-walking loop shared (that part is generic, real work), but delegate the per-parameter dispatch — currently a direct call to `apply_jamf_parameter "$index" ...` — to a provider hook so, e.g., an Intune provider can key off a different field (like `env_var`) instead of `index`.

6. **The interactive wizard's "--- Parameter 4 ---" prompt loop** also needs to delegate to the provider for what to call a parameter, how many slots exist, and whether numeric indices are the right mental model at all — Intune has no positional slots, so its provider might instead prompt for an environment variable or config key name with no index.

---

## Rollout order (by lift, not importance)

- **Kandji first** — closest cousin to Jamf: also uses positional script parameters, and has a Custom Attributes concept analogous to EAs. Mostly a templates/docs swap plus its own deploy API.
- **Mosyle second** — script-based custom commands, similar shape to Kandji.
- **Fleet** — see below. Deploy side is likely cheap; parameter and EA/inventory sides need real design work.
- **Intune last** — biggest lift. No native parameter passing, Graph API deploy, and the generated script body itself has to differ, not just the wrapper around it.
- **`generic` provider** — a safety valve for any MDM without a named provider: env-var-based params, plain-text output, no deploy workflow. Keeps shikomi useful on day one for anything unsupported, and turns "MDM-agnostic" into "MDM-extensible" if provider files are documented and user-droppable.

---

## Fleet as a candidate provider

Fleet ([fleetdm.com](https://fleetdm.com)) is open-source and built API/GitOps-first, which fits Shikomi's git-centric workflow better philosophically than Jamf's UI-first model. It diverges structurally from the other three MDMs in two ways:

**No Jamf-style positional parameters.** Fleet's mechanism is `$FLEET_SECRET_*` token substitution — a variable is defined via the Fleet UI, API, or GitOps YAML (pulling from a repo secret), then referenced in the script body as `$FLEET_SECRET_MYNAME`; Fleet substitutes it at delivery time and masks it in the UI/API. This is a secrets-injection system, not a general parameter-passing mechanism — notably, Fleet does **not** mask the secret from script *output*, so a Fleet provider's generated logging functions would need their own "don't echo this" guidance rather than reusing Jamf's masking pattern. Non-secret configurable values don't appear to have a native passing mechanism at all. This puts Fleet in the same "no native params" bucket as Intune, for a different underlying reason.

**No confirmed Jamf-EA equivalent.** Fleet's inventory model is osquery custom queries (SQL), not shell scripts that output `<result>VALUE</result>`. A Fleet provider likely can't reuse `lib/templates.sh`'s EA template at all — it would need a different generation mode (an osquery query scaffold, not a shell script) for EA parity. Worth confirming directly against current Fleet docs before finalizing.

**Deploy workflow is likely cheaper to build than Jamf's, not more expensive.** Fleet ships `fleetctl` and a first-class `fleet-gitops` YAML configuration (a `scripts:` key referencing file paths, `fleetctl generate-gitops`, and a documented GitHub Actions pattern that runs on push to the default branch). A Fleet provider could plausibly drop the generated script at the path Fleet's own GitOps config expects and let Fleet's existing CI pattern apply it, rather than building a bespoke curl/OAuth-based GitHub Action the way `lib/workflows.sh` does for Jamf. Fleet's REST API also exposes `POST /scripts/run` and `/scripts/run/sync` for on-demand triggering if needed.

**Sources:**
- [Fleet | Custom variables in scripts and configuration profiles](https://fleetdm.com/guides/secrets-in-scripts-and-configuration-profiles)
- [Fleet | Scripts](https://fleetdm.com/guides/scripts)
- [Fleet | GitOps | Fleet documentation](https://fleetdm.com/docs/configuration/yaml-files)
- [GitHub - fleetdm/fleet-gitops](https://github.com/fleetdm/fleet-gitops)
- [Fleet | REST API | Fleet documentation](https://fleetdm.com/docs/rest-api)
