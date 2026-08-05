################################################################################
# LIB:         workflows.sh
# DESCRIPTION: GitHub Actions workflow generation functions for Shikomi
#
# FUNCTIONS:   generate_validate_workflow(), generate_deploy_workflow(),
#              generate_monorepo_validate_workflow(), generate_monorepo_deploy_workflow()
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

          IS_EA=false
          [[ "$SCRIPT_FILE" == *_ea.sh ]] && IS_EA=true
          echo "is_ea=$IS_EA" >> $GITHUB_OUTPUT

          # Use JAMF_NAME header if present, otherwise derive from filename
          JAMF_NAME_HEADER=$(grep "^# JAMF_NAME:" "$SCRIPT_FILE" | sed 's/^# JAMF_NAME: //')
          if [[ -n "$JAMF_NAME_HEADER" ]]; then
            SCRIPT_NAME="$JAMF_NAME_HEADER"
            echo "jamf_name_explicit=true" >> $GITHUB_OUTPUT
          else
            SCRIPT_NAME="${SCRIPT_FILE%.sh}"
            echo "jamf_name_explicit=false" >> $GITHUB_OUTPUT
          fi
          SCRIPT_VERSION=$(grep "^readonly SCRIPT_VERSION=" "$SCRIPT_FILE" | sed 's/.*"\(.*\)".*/\1/')

          # EA-only metadata (no-op grep on regular scripts, falls back to defaults)
          JAMF_DATA_TYPE_HEADER=$(grep "^# JAMF_DATA_TYPE:" "$SCRIPT_FILE" | sed 's/^# JAMF_DATA_TYPE: //')
          echo "data_type=${JAMF_DATA_TYPE_HEADER:-STRING}" >> $GITHUB_OUTPUT
          JAMF_DISPLAY_CATEGORY_HEADER=$(grep "^# JAMF_DISPLAY_CATEGORY:" "$SCRIPT_FILE" | sed 's/^# JAMF_DISPLAY_CATEGORY: //')
          echo "display_category=${JAMF_DISPLAY_CATEGORY_HEADER:-EXTENSION_ATTRIBUTES}" >> $GITHUB_OUTPUT

          echo "script_file=$SCRIPT_FILE" >> $GITHUB_OUTPUT
          echo "script_name=$SCRIPT_NAME" >> $GITHUB_OUTPUT
          echo "script_version=$SCRIPT_VERSION" >> $GITHUB_OUTPUT
          echo "Found: $SCRIPT_FILE (v$SCRIPT_VERSION), Jamf name: $SCRIPT_NAME"

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
          IS_EA="${{ steps.find_script.outputs.is_ea }}"
          SCRIPT_NAME="${{ steps.find_script.outputs.script_name }}"
          JAMF_NAME_EXPLICIT="${{ steps.find_script.outputs.jamf_name_explicit }}"
          TOKEN="${{ steps.auth.outputs.token }}"

          if [[ "$IS_EA" == "true" ]]; then
            ENDPOINT="${JAMF_URL}/api/v1/computer-extension-attributes"
          else
            ENDPOINT="${JAMF_URL}/api/v1/scripts"
          fi

          # Search for object by exact Jamf name
          RESPONSE=$(curl -s -G "$ENDPOINT" \
            --data-urlencode "filter=name==\"${SCRIPT_NAME}\"" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Accept: application/json")
          OBJECT_ID=$(echo "$RESPONSE" | jq -r '.results[0].id // empty')

          if [[ -z "$OBJECT_ID" && "$JAMF_NAME_EXPLICIT" != "true" && "$IS_EA" != "true" ]]; then
            # Retry with .sh extension (Scripts-only back-compat; EA filenames
            # always end _ea.sh so there's no equivalent naming ambiguity)
            RESPONSE=$(curl -s -G "$ENDPOINT" \
              --data-urlencode "filter=name==\"${SCRIPT_NAME}.sh\"" \
              -H "Authorization: Bearer ${TOKEN}" \
              -H "Accept: application/json")
            OBJECT_ID=$(echo "$RESPONSE" | jq -r '.results[0].id // empty')
          fi

          if [[ -n "$OBJECT_ID" ]]; then
            echo "Found existing object: $SCRIPT_NAME (ID: $OBJECT_ID)"
            echo "action=update" >> $GITHUB_OUTPUT
            echo "object_id=$OBJECT_ID" >> $GITHUB_OUTPUT
          else
            echo "Object not found in Jamf Pro, will create new"
            echo "action=create" >> $GITHUB_OUTPUT
          fi

      - name: Deploy script to Jamf Pro
        env:
          JAMF_URL: ${{ secrets.JAMF_URL }}
        run: |
          TOKEN="${{ steps.auth.outputs.token }}"
          IS_EA="${{ steps.find_script.outputs.is_ea }}"
          SCRIPT_NAME="${{ steps.find_script.outputs.script_name }}"
          SCRIPT_VERSION="${{ steps.find_script.outputs.script_version }}"
          ACTION="${{ steps.lookup.outputs.action }}"
          OBJECT_ID="${{ steps.lookup.outputs.object_id }}"

          # Build JSON payload
          if [[ "$IS_EA" == "true" ]]; then
            ENDPOINT="${JAMF_URL}/api/v1/computer-extension-attributes"
            DATA_TYPE="${{ steps.find_script.outputs.data_type }}"
            DISPLAY_CATEGORY="${{ steps.find_script.outputs.display_category }}"
            PAYLOAD=$(jq -n \
              --arg name "$SCRIPT_NAME" \
              --arg description "Deployed from GitHub (v${SCRIPT_VERSION})" \
              --arg dataType "$DATA_TYPE" \
              --arg inventoryDisplayType "$DISPLAY_CATEGORY" \
              --arg contents "$(cat /tmp/script_payload.txt)" \
              '{
                name: $name,
                description: $description,
                dataType: $dataType,
                inputType: "SCRIPT",
                inventoryDisplayType: $inventoryDisplayType,
                scriptContents: $contents,
                enabled: true
              }')
          else
            ENDPOINT="${JAMF_URL}/api/v1/scripts"
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
          fi

          if [[ "$ACTION" == "update" ]]; then
            echo "Updating $SCRIPT_NAME (ID: $OBJECT_ID)..."
            HTTP_CODE=$(curl -s -o /tmp/response.json -w "%{http_code}" \
              -X PUT "${ENDPOINT}/${OBJECT_ID}" \
              -H "Authorization: Bearer ${TOKEN}" \
              -H "Content-Type: application/json" \
              -d "$PAYLOAD")
          else
            echo "Creating $SCRIPT_NAME..."
            HTTP_CODE=$(curl -s -o /tmp/response.json -w "%{http_code}" \
              -X POST "${ENDPOINT}" \
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
          echo "**Type:** $([ "${{ steps.find_script.outputs.is_ea }}" == "true" ] && echo "Extension Attribute" || echo "Script")" >> $GITHUB_STEP_SUMMARY
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

function generate_monorepo_validate_workflow() {
    local target_dir="$1"
    mkdir -p "$target_dir/.github/workflows"

    cat > "$target_dir/.github/workflows/validate-scripts.yml" << 'WORKFLOW_EOF'
name: Validate Scripts

on:
  pull_request:
    branches: [ main, master ]
    paths:
      - '**.sh'

jobs:
  shellcheck:
    name: ShellCheck Changed Scripts
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Find changed shell scripts
        id: changed
        run: |
          CHANGED=$(git diff --name-only --diff-filter=ACM origin/${{ github.base_ref }}...HEAD -- '*.sh' | grep -v 'bump-version.sh' || true)
          if [[ -z "$CHANGED" ]]; then
            echo "No shell scripts changed in this PR."
            echo "skip=true" >> $GITHUB_OUTPUT
          else
            echo "Changed scripts:"
            echo "$CHANGED"
            echo "$CHANGED" > /tmp/changed_scripts.txt
            echo "count=$(echo "$CHANGED" | wc -l | tr -d ' ')" >> $GITHUB_OUTPUT
          fi

      - name: Install ShellCheck
        if: steps.changed.outputs.skip != 'true'
        run: sudo apt-get install -y shellcheck

      - name: Run ShellCheck on changed scripts
        if: steps.changed.outputs.skip != 'true'
        run: |
          ERRORS=0
          while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            echo "Checking: $file"
            if shellcheck --severity=warning "$file"; then
              echo "  PASS"
            else
              echo "  FAIL"
              ERRORS=$((ERRORS + 1))
            fi
          done < /tmp/changed_scripts.txt

          if [[ $ERRORS -gt 0 ]]; then
            echo ""
            echo "ShellCheck found issues in $ERRORS file(s)"
            exit 1
          fi
          echo ""
          echo "All ${{ steps.changed.outputs.count }} script(s) passed ShellCheck"

  betterleaks:
    name: Secret Scanning
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Run Betterleaks
        run: docker run --rm -v "${{ github.workspace }}:/repo" ghcr.io/betterleaks/betterleaks:latest git /repo -v
WORKFLOW_EOF

    git add "$target_dir/.github/workflows/validate-scripts.yml"
    echo "✓ validate-scripts.yml created (monorepo — validates changed scripts only)"
}

function generate_monorepo_deploy_workflow() {
    local target_dir="$1"
    mkdir -p "$target_dir/.github/workflows"

    cat > "$target_dir/.github/workflows/deploy-to-jamf.yml" << 'DEPLOY_EOF'
name: Deploy Scripts to Jamf Pro

on:
  push:
    branches: [ main, master ]
    paths:
      - '**.sh'

permissions:
  contents: read

jobs:
  deploy:
    name: Deploy Changed Scripts to Jamf Pro
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Detect changed versioned scripts
        id: detect
        run: |
          # Find all .sh files changed in this push (anywhere in repo)
          CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD -- '*.sh')

          if [[ -z "$CHANGED_FILES" ]]; then
            echo "No .sh files changed in this push."
            echo "skip=true" >> $GITHUB_OUTPUT
            exit 0
          fi

          # Filter to only versioned scripts (have readonly SCRIPT_VERSION=)
          DEPLOY_LIST=""
          DEPLOY_COUNT=0
          SKIPPED=""
          for file in $CHANGED_FILES; do
            # Skip deleted files
            if [[ ! -f "$file" ]]; then
              SKIPPED="${SKIPPED}${file} (deleted)"$'\n'
              continue
            fi
            # Skip bump-version.sh anywhere in the repo
            if [[ "$(basename "$file")" == "bump-version.sh" ]]; then
              continue
            fi
            # Only deploy scripts with readonly SCRIPT_VERSION=
            if grep -q "^readonly SCRIPT_VERSION=" "$file" 2>/dev/null; then
              DEPLOY_LIST="${DEPLOY_LIST}${file}"$'\n'
              DEPLOY_COUNT=$((DEPLOY_COUNT + 1))
            else
              SKIPPED="${SKIPPED}${file} (no SCRIPT_VERSION)"$'\n'
            fi
          done

          if [[ $DEPLOY_COUNT -eq 0 ]]; then
            echo "No versioned scripts changed. Skipping deployment."
            if [[ -n "$SKIPPED" ]]; then
              echo "Skipped files:"
              echo "$SKIPPED"
            fi
            echo "skip=true" >> $GITHUB_OUTPUT
            exit 0
          fi

          echo "Found $DEPLOY_COUNT versioned script(s) to deploy:"
          echo "$DEPLOY_LIST"

          # Write deploy list for next step
          printf '%s' "$DEPLOY_LIST" > /tmp/deploy_list.txt
          echo "count=$DEPLOY_COUNT" >> $GITHUB_OUTPUT

      - name: Authenticate to Jamf Pro
        if: steps.detect.outputs.skip != 'true'
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

      - name: Deploy changed scripts
        if: steps.detect.outputs.skip != 'true'
        env:
          JAMF_URL: ${{ secrets.JAMF_URL }}
        run: |
          TOKEN="${{ steps.auth.outputs.token }}"
          SUCCESS=0
          FAILED=0
          SUMMARY=""

          while IFS= read -r file; do
            [[ -z "$file" ]] && continue

            IS_EA=false
            [[ "$file" == *_ea.sh ]] && IS_EA=true
            TYPE=$([ "$IS_EA" == true ] && echo "EA" || echo "Script")

            # Use JAMF_NAME header if present, otherwise derive from filename
            JAMF_NAME_HEADER=$(grep "^# JAMF_NAME:" "$file" | sed 's/^# JAMF_NAME: //')
            if [[ -n "$JAMF_NAME_HEADER" ]]; then
              SCRIPT_NAME="$JAMF_NAME_HEADER"
              JAMF_NAME_EXPLICIT=true
            else
              SCRIPT_NAME="$(basename "${file%.sh}")"
              JAMF_NAME_EXPLICIT=false
            fi
            SCRIPT_VERSION=$(grep "^readonly SCRIPT_VERSION=" "$file" | sed 's/.*"\(.*\)".*/\1/')

            # EA-only metadata (no-op grep on regular scripts, falls back to defaults)
            JAMF_DATA_TYPE_HEADER=$(grep "^# JAMF_DATA_TYPE:" "$file" | sed 's/^# JAMF_DATA_TYPE: //')
            DATA_TYPE="${JAMF_DATA_TYPE_HEADER:-STRING}"
            JAMF_DISPLAY_CATEGORY_HEADER=$(grep "^# JAMF_DISPLAY_CATEGORY:" "$file" | sed 's/^# JAMF_DISPLAY_CATEGORY: //')
            DISPLAY_CATEGORY="${JAMF_DISPLAY_CATEGORY_HEADER:-EXTENSION_ATTRIBUTES}"

            echo ""
            echo "=== Deploying: $SCRIPT_NAME v$SCRIPT_VERSION ($TYPE, from $file) ==="

            if [[ "$IS_EA" == true ]]; then
              ENDPOINT="${JAMF_URL}/api/v1/computer-extension-attributes"
            else
              ENDPOINT="${JAMF_URL}/api/v1/scripts"
            fi

            # Look up in Jamf Pro by exact name
            OBJECT_ID=""
            RESPONSE=$(curl -s -G "$ENDPOINT" \
              --data-urlencode "filter=name==\"${SCRIPT_NAME}\"" \
              -H "Authorization: Bearer ${TOKEN}" \
              -H "Accept: application/json")
            OBJECT_ID=$(echo "$RESPONSE" | jq -r '.results[0].id // empty')

            if [[ -z "$OBJECT_ID" && "$JAMF_NAME_EXPLICIT" != "true" && "$IS_EA" != true ]]; then
              # Retry with .sh extension (Scripts-only back-compat; EA filenames
              # always end _ea.sh so there's no equivalent naming ambiguity)
              RESPONSE=$(curl -s -G "$ENDPOINT" \
                --data-urlencode "filter=name==\"${SCRIPT_NAME}.sh\"" \
                -H "Authorization: Bearer ${TOKEN}" \
                -H "Accept: application/json")
              OBJECT_ID=$(echo "$RESPONSE" | jq -r '.results[0].id // empty')
            fi

            # Build JSON payload
            if [[ "$IS_EA" == true ]]; then
              PAYLOAD=$(jq -n \
                --arg name "$SCRIPT_NAME" \
                --arg description "Deployed from GitHub (v${SCRIPT_VERSION})" \
                --arg dataType "$DATA_TYPE" \
                --arg inventoryDisplayType "$DISPLAY_CATEGORY" \
                --arg contents "$(cat "$file")" \
                '{
                  name: $name,
                  description: $description,
                  dataType: $dataType,
                  inputType: "SCRIPT",
                  inventoryDisplayType: $inventoryDisplayType,
                  scriptContents: $contents,
                  enabled: true
                }')
            else
              PAYLOAD=$(jq -n \
                --arg name "$SCRIPT_NAME" \
                --arg info "Deployed from GitHub (v${SCRIPT_VERSION})" \
                --arg contents "$(cat "$file")" \
                '{
                  name: $name,
                  info: $info,
                  scriptContents: $contents,
                  priority: "AFTER",
                  categoryId: "-1"
                }')
            fi

            # Create or update
            if [[ -n "$OBJECT_ID" ]]; then
              ACTION="update"
              echo "  Found existing $TYPE (ID: $OBJECT_ID), updating..."
              HTTP_CODE=$(curl -s -o /tmp/response.json -w "%{http_code}" \
                -X PUT "${ENDPOINT}/${OBJECT_ID}" \
                -H "Authorization: Bearer ${TOKEN}" \
                -H "Content-Type: application/json" \
                -d "$PAYLOAD")
            else
              ACTION="create"
              echo "  $TYPE not found in Jamf Pro, creating..."
              HTTP_CODE=$(curl -s -o /tmp/response.json -w "%{http_code}" \
                -X POST "${ENDPOINT}" \
                -H "Authorization: Bearer ${TOKEN}" \
                -H "Content-Type: application/json" \
                -d "$PAYLOAD")
            fi

            if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
              echo "  SUCCESS: $SCRIPT_NAME v${SCRIPT_VERSION} deployed (HTTP $HTTP_CODE)"
              SUCCESS=$((SUCCESS + 1))
              SUMMARY="${SUMMARY}| ${SCRIPT_NAME} | ${SCRIPT_VERSION} | ${TYPE} | ${ACTION} | ${file} | success |\n"
            else
              echo "  FAILED: $SCRIPT_NAME deployment failed (HTTP $HTTP_CODE)"
              cat /tmp/response.json | jq . 2>/dev/null || cat /tmp/response.json
              FAILED=$((FAILED + 1))
              SUMMARY="${SUMMARY}| ${SCRIPT_NAME} | ${SCRIPT_VERSION} | ${TYPE} | ${ACTION} | ${file} | **FAILED** |\n"
            fi
          done < /tmp/deploy_list.txt

          echo ""
          echo "=== Results: $SUCCESS deployed, $FAILED failed ==="

          # Save summary for next step
          echo "$SUCCESS" > /tmp/deploy_success.txt
          echo "$FAILED" > /tmp/deploy_failed.txt
          printf '%b' "$SUMMARY" > /tmp/deploy_summary.txt

          # Fail the workflow if any deployments failed
          if [[ $FAILED -gt 0 ]]; then
            exit 1
          fi

      - name: Deployment summary
        if: always() && steps.detect.outputs.skip != 'true'
        run: |
          SUCCESS=$(cat /tmp/deploy_success.txt 2>/dev/null || echo "0")
          FAILED=$(cat /tmp/deploy_failed.txt 2>/dev/null || echo "0")

          {
            echo "## Deployment Summary"
            echo ""
            echo "**Deployed:** ${SUCCESS} | **Failed:** ${FAILED}"
            echo ""
            echo "| Script | Version | Type | Action | Path | Status |"
            echo "|--------|---------|------|--------|------|--------|"
            cat /tmp/deploy_summary.txt 2>/dev/null || echo "| — | — | — | — | — | No results |"
            echo ""
            echo "**Commit:** ${{ github.sha }}"
          } >> $GITHUB_STEP_SUMMARY
DEPLOY_EOF

    echo "✓ deploy-to-jamf.yml created (monorepo — deploys changed versioned scripts)"
    echo ""
    echo "Required GitHub Secrets for deployment:"
    echo "  JAMF_CLIENT_ID     - API client ID from Jamf Pro"
    echo "  JAMF_CLIENT_SECRET - API client secret from Jamf Pro"
    echo "  JAMF_URL           - Jamf Pro URL (e.g. https://yourinstance.jamfcloud.com)"
    echo ""
    git add "$target_dir/.github/workflows/deploy-to-jamf.yml"
}
