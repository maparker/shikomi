# Jamf Pro API Setup Reference

How to configure Jamf Pro and GitHub for automated script deployment.

---

## 1. Create an API Role in Jamf Pro

1. Log in to Jamf Pro
2. Go to **Settings > System > API Roles and Clients**
3. Click **New** under API Roles
4. Name the role (e.g. `GitHub Script Deployer`)
5. Add these permissions:

| Permission | Required |
|------------|----------|
| Read Scripts | Yes |
| Create Scripts | Yes |
| Update Scripts | Yes |

6. Click **Save**

---

## 2. Create an API Client in Jamf Pro

1. Still in **API Roles and Clients**, click **New** under API Clients
2. Name the client (e.g. `github-deploy`)
3. Assign the role you created in step 1
4. Set the access token lifetime (recommended: 300 seconds)
5. Click **Save**
6. Copy the **Client ID** and **Client Secret**

> **Important**: The client secret is only shown once. Copy it immediately.

---

## 3. Add Secrets to Your GitHub Repository

1. Go to your GitHub repository
2. Navigate to **Settings > Secrets and variables > Actions**
3. Click **New repository secret** for each:

| Secret Name | Value |
|-------------|-------|
| `JAMF_URL` | Your Jamf Pro URL (e.g. `https://yourinstance.jamfcloud.com`) |
| `JAMF_CLIENT_ID` | The client ID from step 2 |
| `JAMF_CLIENT_SECRET` | The client secret from step 2 |

> **Note**: Do not include a trailing slash on the `JAMF_URL`.

---

## 4. Verify the Setup

After merging your first pull request to `main`, check that the deployment succeeded:

### In GitHub

1. Go to the **Actions** tab in your repository
2. Find the **Deploy Script to Jamf Pro** workflow run
3. Check the deployment summary for status and version

### In Jamf Pro

1. Go to **Settings > Computer Management > Scripts**
2. Search for your script name
3. Verify the script contents match your repository
4. Check the **Info** field shows the version (e.g. `Deployed from GitHub (v1.0.0)`)

---

## How the Workflow Authenticates

```
GitHub Actions                         Jamf Pro
──────────────                         ────────

POST /api/oauth/token ──────────────→  Validates client credentials
  client_id + client_secret              ↓
                                       Returns bearer token
                        ←──────────────
Uses token for all
subsequent API calls
  GET  /api/v1/scripts  ─────────────→  Look up script by name
  POST /api/v1/scripts  ─────────────→  Create new script
  PUT  /api/v1/scripts/{id} ─────────→  Update existing script
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `Failed to authenticate` | Wrong client ID or secret | Regenerate the client secret in Jamf Pro and update the GitHub secret |
| `Missing required secrets` | Secrets not configured | Add all three secrets to your repository (Settings > Secrets) |
| `No versioned script found` | Script missing `SCRIPT_VERSION` | Ensure your script has `readonly SCRIPT_VERSION="x.y.z"` |
| `Deployment failed (HTTP 403)` | Insufficient API permissions | Verify the API role has Read, Create, and Update Scripts permissions |
| `Deployment failed (HTTP 409)` | Script name conflict | Check for duplicate script names in Jamf Pro |

---

## Security Notes

- API credentials are stored as GitHub encrypted secrets and never appear in logs
- The bearer token is masked in workflow output using `::add-mask::`
- The workflow runs with `permissions: contents: read` (minimal access)
- Jamf Pro API tokens expire after the configured lifetime (no persistent access)
