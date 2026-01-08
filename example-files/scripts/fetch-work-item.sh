#!/bin/bash
# fetch-work-item.sh
# Fetches work item details from Azure DevOps REST API
#
# Usage: ./fetch-work-item.sh <work-item-id> <access-token> <output-file>

set -e

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-functions.sh"

WORK_ITEM_ID="$1"
ACCESS_TOKEN="$2"
OUTPUT_FILE="$3"

if [ -z "$WORK_ITEM_ID" ] || [ -z "$ACCESS_TOKEN" ] || [ -z "$OUTPUT_FILE" ]; then
  echo "Usage: $0 <work-item-id> <access-token> <output-file>"
  exit 1
fi

# Initialize Azure defaults (sets ORG, PROJECT, API_BASE)
init_azure_defaults

echo "Fetching work item #$WORK_ITEM_ID from $ORG/$PROJECT..."

# Fetch work item with all fields
API_URL="${API_BASE}/wit/workitems/$WORK_ITEM_ID?api-version=7.0"

HTTP_STATUS=$(curl -s -w "%{http_code}" -o "$OUTPUT_FILE" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  "$API_URL")

if ! validate_http_status "$HTTP_STATUS" "200" "Fetch work item"; then
  cat "$OUTPUT_FILE"
  exit 1
fi

# Validate JSON
if ! validate_json "$OUTPUT_FILE" "work item response"; then
  exit 1
fi

# Display summary
TITLE=$(jq -r '.fields["System.Title"]' "$OUTPUT_FILE")
STATE=$(jq -r '.fields["System.State"]' "$OUTPUT_FILE")
TYPE=$(jq -r '.fields["System.WorkItemType"]' "$OUTPUT_FILE")

echo "----------------------------------------"
echo "Work Item: #$WORK_ITEM_ID"
echo "Type: $TYPE"
echo "Title: $TITLE"
echo "State: $STATE"
echo "----------------------------------------"
echo "Saved to: $OUTPUT_FILE"
