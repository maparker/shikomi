################################################################################
# LIB:         workflows.sh
# DESCRIPTION: GitHub Actions workflow generation functions for Shikomi
#
# FUNCTIONS:   generate_validate_workflow(), generate_deploy_workflow()
#
# GLOBALS READ: None
# GLOBALS WRITTEN: None (writes YAML files to target directory)
################################################################################

function generate_validate_workflow() {
    local target_dir="$1"
    mkdir -p "$target_dir/.github/workflows"

    cat > "$target_dir/.github/workflows/validate-version.yml" << 'WORKFLOW_EOF'
name: Validate Version

on:
  pull_request:
    branches: [ main, master ]
  push:
    tags:
      - 'v*'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Extract version from script
        id: script_version
        run: |
          # Find versioned script (same logic as bump-version.sh)
          SCRIPT_FILE=""
          shopt -s nullglob
          for file in *.sh; do
            if [[ "$file" != "bump-version.sh" ]] && grep -q "^readonly SCRIPT_VERSION=" "$file" 2>/dev/null; then
              SCRIPT_FILE="$file"
              break
            fi
          done

          if [[ -z "$SCRIPT_FILE" ]]; then
            echo "Error: No versioned script found"
            exit 1
          fi

          echo "Found script: $SCRIPT_FILE"
          VERSION=$(grep "^readonly SCRIPT_VERSION=" "$SCRIPT_FILE" | sed 's/.*"\(.*\)".*/\1/')
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "Script version: $VERSION"

      - name: Extract version from README
        id: readme_version
        run: |
          VERSION=$(grep "^\*\*Version:\*\*" README.md | sed 's/.*: \(.*\)$/\1/')
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "README version: $VERSION"

      - name: Validate versions match
        run: |
          if [ "${{ steps.script_version.outputs.version }}" != "${{ steps.readme_version.outputs.version }}" ]; then
            echo "ERROR: Version mismatch!"
            echo "Script: ${{ steps.script_version.outputs.version }}"
            echo "README: ${{ steps.readme_version.outputs.version }}"
            exit 1
          fi
          echo "SUCCESS: Versions match: ${{ steps.script_version.outputs.version }}"

      - name: Validate tag matches version (on tag push)
        if: startsWith(github.ref, 'refs/tags/')
        run: |
          TAG_VERSION=${GITHUB_REF#refs/tags/v}
          SCRIPT_VERSION="${{ steps.script_version.outputs.version }}"
          if [ "$TAG_VERSION" != "$SCRIPT_VERSION" ]; then
            echo "ERROR: Tag version ($TAG_VERSION) does not match script version ($SCRIPT_VERSION)"
            exit 1
          fi
          echo "SUCCESS: Tag matches version: v$SCRIPT_VERSION"

  shellcheck:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run ShellCheck
        uses: ludeeus/action-shellcheck@master
        with:
          ignore_paths: .github
WORKFLOW_EOF

    git add "$target_dir/.github/workflows/validate-version.yml"
    echo "✓ validate-version.yml created"
}

function generate_deploy_workflow() {
    local target_dir="$1"
    mkdir -p "$target_dir/.github/workflows"

    cat > "$target_dir/.github/workflows/deploy-to-jamf.yml" << 'DEPLOY_EOF'
name: Deploy Script to Jamf Pro

on:
  push:
    branches: [ main, master ]
    paths:
      - '*.sh'
      - '!bump-version.sh'

permissions:
  contents: read

jobs:
  deploy:
    name: Deploy to Jamf Pro
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Find versioned script
        id: find_script
        run: |
          SCRIPT_FILE=""
          for file in *.sh; do
            if [[ "$file" != "bump-version.sh" ]] && grep -q "^readonly SCRIPT_VERSION=" "$file" 2>/dev/null; then
              SCRIPT_FILE="$file"
              break
            fi
          done

          if [[ -z "$SCRIPT_FILE" ]]; then
            echo "Error: No versioned script found"
            exit 1
          fi

          SCRIPT_NAME="${SCRIPT_FILE%.sh}"
          SCRIPT_VERSION=$(grep "^readonly SCRIPT_VERSION=" "$SCRIPT_FILE" | sed 's/.*"\(.*\)".*/\1/')

          echo "script_file=$SCRIPT_FILE" >> $GITHUB_OUTPUT
          echo "script_name=$SCRIPT_NAME" >> $GITHUB_OUTPUT
          echo "script_version=$SCRIPT_VERSION" >> $GITHUB_OUTPUT
          echo "Found: $SCRIPT_FILE (v$SCRIPT_VERSION)"

      - name: Authenticate to Jamf Pro
        id: auth
        env:
          JAMF_CLIENT_ID: ${{ secrets.JAMF_CLIENT_ID }}
          JAMF_CLIENT_SECRET: ${{ secrets.JAMF_CLIENT_SECRET }}
          JAMF_URL: ${{ secrets.JAMF_URL }}
        run: |
          if [[ -z "$JAMF_CLIENT_ID" || -z "$JAMF_CLIENT_SECRET" || -z "$JAMF_URL" ]]; then
            echo "Error: Missing required secrets (JAMF_CLIENT_ID, JAMF_CLIENT_SECRET, JAMF_URL)"
            exit 1
          fi

          RESPONSE=$(curl -s -X POST "${JAMF_URL}/api/oauth/token" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "client_id=${JAMF_CLIENT_ID}&client_secret=${JAMF_CLIENT_SECRET}&grant_type=client_credentials")

          TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')

          if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
            echo "Error: Failed to authenticate to Jamf Pro"
            echo "$RESPONSE" | jq .
            exit 1
          fi

          echo "::add-mask::$TOKEN"
          echo "token=$TOKEN" >> $GITHUB_OUTPUT
          echo "Authenticated to Jamf Pro"

      - name: Read script content
        id: script_content
        run: |
          SCRIPT_CONTENT=$(cat "${{ steps.find_script.outputs.script_file }}")
          # Write to a temp file for the API call (avoids shell escaping issues)
          echo "$SCRIPT_CONTENT" > /tmp/script_payload.txt
          echo "Script content read (${{ steps.find_script.outputs.script_file }})"

      - name: Look up existing script in Jamf Pro
        id: lookup
        env:
          JAMF_URL: ${{ secrets.JAMF_URL }}
        run: |
          SCRIPT_NAME="${{ steps.find_script.outputs.script_name }}"
          TOKEN="${{ steps.auth.outputs.token }}"

          # Search for script by name
          RESPONSE=$(curl -s -X GET "${JAMF_URL}/api/v1/scripts?filter=name==%22${SCRIPT_NAME}%22" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Accept: application/json")

          SCRIPT_ID=$(echo "$RESPONSE" | jq -r '.results[0].id // empty')

          if [[ -n "$SCRIPT_ID" ]]; then
            echo "Found existing script: $SCRIPT_NAME (ID: $SCRIPT_ID)"
            echo "action=update" >> $GITHUB_OUTPUT
            echo "script_id=$SCRIPT_ID" >> $GITHUB_OUTPUT
          else
            echo "Script not found in Jamf Pro, will create new"
            echo "action=create" >> $GITHUB_OUTPUT
          fi

      - name: Deploy script to Jamf Pro
        env:
          JAMF_URL: ${{ secrets.JAMF_URL }}
        run: |
          TOKEN="${{ steps.auth.outputs.token }}"
          SCRIPT_NAME="${{ steps.find_script.outputs.script_name }}"
          SCRIPT_VERSION="${{ steps.find_script.outputs.script_version }}"
          ACTION="${{ steps.lookup.outputs.action }}"
          SCRIPT_ID="${{ steps.lookup.outputs.script_id }}"

          # Build JSON payload
          PAYLOAD=$(jq -n \
            --arg name "$SCRIPT_NAME" \
            --arg info "Deployed from GitHub (v${SCRIPT_VERSION})" \
            --arg contents "$(cat /tmp/script_payload.txt)" \
            '{
              name: $name,
              info: $info,
              scriptContents: $contents,
              priority: "AFTER",
              categoryId: "-1"
            }')

          if [[ "$ACTION" == "update" ]]; then
            echo "Updating script $SCRIPT_NAME (ID: $SCRIPT_ID)..."
            HTTP_CODE=$(curl -s -o /tmp/response.json -w "%{http_code}" \
              -X PUT "${JAMF_URL}/api/v1/scripts/${SCRIPT_ID}" \
              -H "Authorization: Bearer ${TOKEN}" \
              -H "Content-Type: application/json" \
              -d "$PAYLOAD")
          else
            echo "Creating script $SCRIPT_NAME..."
            HTTP_CODE=$(curl -s -o /tmp/response.json -w "%{http_code}" \
              -X POST "${JAMF_URL}/api/v1/scripts" \
              -H "Authorization: Bearer ${TOKEN}" \
              -H "Content-Type: application/json" \
              -d "$PAYLOAD")
          fi

          if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
            echo "Successfully deployed $SCRIPT_NAME v${SCRIPT_VERSION} to Jamf Pro (HTTP $HTTP_CODE)"
          else
            echo "Error: Deployment failed (HTTP $HTTP_CODE)"
            cat /tmp/response.json | jq . 2>/dev/null || cat /tmp/response.json
            exit 1
          fi

      - name: Deployment summary
        if: always()
        run: |
          echo "## Deployment Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Script:** ${{ steps.find_script.outputs.script_name }}" >> $GITHUB_STEP_SUMMARY
          echo "**Version:** ${{ steps.find_script.outputs.script_version }}" >> $GITHUB_STEP_SUMMARY
          echo "**Action:** ${{ steps.lookup.outputs.action }}" >> $GITHUB_STEP_SUMMARY
          echo "**Commit:** ${{ github.sha }}" >> $GITHUB_STEP_SUMMARY
DEPLOY_EOF

    echo "✓ deploy-to-jamf.yml created"
    echo ""
    echo "Required GitHub Secrets for deployment:"
    echo "  JAMF_CLIENT_ID     - API client ID from Jamf Pro"
    echo "  JAMF_CLIENT_SECRET - API client secret from Jamf Pro"
    echo "  JAMF_URL           - Jamf Pro URL (e.g. https://yourinstance.jamfcloud.com)"
    echo ""
    git add "$target_dir/.github/workflows/deploy-to-jamf.yml"
}
