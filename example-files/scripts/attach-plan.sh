#!/bin/bash
# attach-plan.sh
# Attaches an implementation plan file to an Azure DevOps work item
#
# Usage: ./attach-plan.sh <work-item-id> <plan-file-path> <access-token>

set -e

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-functions.sh"

WORK_ITEM_ID="$1"
PLAN_FILE="$2"
ACCESS_TOKEN="$3"

if [ -z "$WORK_ITEM_ID" ] || [ -z "$PLAN_FILE" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "Usage: $0 <work-item-id> <plan-file-path> <access-token>"
  exit 1
fi

if [ ! -f "$PLAN_FILE" ]; then
  echo "Error: Plan file not found: $PLAN_FILE"
  exit 1
fi

# Initialize Azure defaults (sets ORG, PROJECT, API_BASE)
init_azure_defaults

echo "Attaching plan to work item #$WORK_ITEM_ID..."

# Generate filename with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILENAME="implementation-plan-${TIMESTAMP}.md"

# Step 1: Upload the attachment
echo "Uploading attachment..."
UPLOAD_URL="${API_BASE}/wit/attachments?fileName=$FILENAME&api-version=7.0"

UPLOAD_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"$PLAN_FILE" \
  "$UPLOAD_URL")

# Extract attachment URL from response
ATTACHMENT_URL=$(echo "$UPLOAD_RESPONSE" | jq -r '.url')

if [ -z "$ATTACHMENT_URL" ] || [ "$ATTACHMENT_URL" == "null" ]; then
  echo "Error: Failed to upload attachment"
  echo "$UPLOAD_RESPONSE"
  exit 1
fi

echo "Attachment uploaded: $ATTACHMENT_URL"

# Step 2: Link attachment to work item
echo "Linking attachment to work item..."
LINK_URL="${API_BASE}/wit/workitems/$WORK_ITEM_ID?api-version=7.0"

LINK_PAYLOAD=$(cat <<EOF
[
  {
    "op": "add",
    "path": "/relations/-",
    "value": {
      "rel": "AttachedFile",
      "url": "$ATTACHMENT_URL",
      "attributes": {
        "name": "$FILENAME",
        "comment": "AI-generated implementation plan"
      }
    }
  }
]
EOF
)

HTTP_STATUS=$(curl -s -w "%{http_code}" -o /tmp/link-response.json \
  -X PATCH \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json-patch+json" \
  -d "$LINK_PAYLOAD" \
  "$LINK_URL")

if ! validate_http_status "$HTTP_STATUS" "200" "Link attachment to work item"; then
  cat /tmp/link-response.json
  exit 1
fi

echo "----------------------------------------"
echo "Plan attached successfully!"
echo "Work Item: #$WORK_ITEM_ID"
echo "Filename: $FILENAME"
echo "----------------------------------------"

# Step 3: Add a comment about the plan
echo "Adding comment to work item..."

# Generate simple summary from plan
PLAN_TITLE=$(grep -m1 '^# ' "$PLAN_FILE" | sed 's/^# //' || echo "Implementation Plan")
PHASE_COUNT=$(grep -c '^## ' "$PLAN_FILE" || echo "0")
FILE_COUNT=$(grep -oE '\b[a-zA-Z0-9_/-]+\.(ts|tsx|js|jsx|css|sql|json)\b' "$PLAN_FILE" | sort -u | wc -l | tr -d ' ')

COMMENT_TEXT="IMPLEMENTATION PLAN GENERATED

An AI-generated implementation plan has been attached to this work item.

Summary:
- Title: ${PLAN_TITLE}
- Phases: ${PHASE_COUNT}
- Files: ~${FILE_COUNT}

Next Steps:
1. Review the attached plan
2. If approved, move this item to 'AI Implement' status
3. If changes needed, update the acceptance criteria and re-run planning"

# Use the reusable comment script
"$SCRIPT_DIR/add-work-item-comment.sh" "$WORK_ITEM_ID" "$COMMENT_TEXT" "$ACCESS_TOKEN"
