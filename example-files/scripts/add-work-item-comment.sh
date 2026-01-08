#!/bin/bash
# add-work-item-comment.sh
# Adds a comment to an Azure DevOps work item
#
# Usage: ./add-work-item-comment.sh <work-item-id> <comment-text> <access-token>
#
# Environment variables (required):
#   AZURE_DEVOPS_ORG     - Azure DevOps organization
#   AZURE_DEVOPS_PROJECT - Azure DevOps project name

set -e

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-functions.sh"

WORK_ITEM_ID="$1"
COMMENT_TEXT="$2"
ACCESS_TOKEN="$3"

if [ -z "$WORK_ITEM_ID" ] || [ -z "$COMMENT_TEXT" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "Usage: $0 <work-item-id> <comment-text> <access-token>"
  echo ""
  echo "Adds a comment to an Azure DevOps work item."
  echo ""
  echo "Required environment variables:"
  echo "  AZURE_DEVOPS_ORG     - Azure DevOps organization"
  echo "  AZURE_DEVOPS_PROJECT - Azure DevOps project name"
  exit 1
fi

# Initialize Azure defaults
init_azure_defaults

COMMENT_URL="${API_BASE}/wit/workitems/${WORK_ITEM_ID}/comments?api-version=7.0-preview.3"

# Make the API request
HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg text "$COMMENT_TEXT" '{text: $text}')" \
  "$COMMENT_URL")

# Extract status code (last line) and response body
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')

# Check for success (2xx status codes)
if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
  echo "Comment added to work item #$WORK_ITEM_ID"
  exit 0
else
  echo "Error: Failed to add comment. HTTP Status: $HTTP_STATUS"
  echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
  exit 1
fi
