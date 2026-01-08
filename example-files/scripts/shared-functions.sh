#!/bin/bash
# shared-functions.sh
# Common utility functions for Azure DevOps and GitHub integration scripts
#
# Usage: source ./shared-functions.sh

# URL encode a string (handles spaces and common special characters)
# Usage: url_encode "My Project" → "My%20Project"
url_encode() {
  local string="$1"
  echo "$string" | sed 's/ /%20/g'
}

# Get the Azure DevOps API base URL for a project
# Usage: azure_api_base "myOrg" "My Project"
# Returns: https://dev.azure.com/myOrg/My%20Project/_apis
azure_api_base() {
  local org="$1"
  local project="$2"
  local project_encoded
  project_encoded=$(url_encode "$project")
  echo "https://dev.azure.com/${org}/${project_encoded}/_apis"
}

# Get Azure DevOps settings from environment (required)
# Sets: ORG, PROJECT, API_BASE
init_azure_defaults() {
  ORG="${AZURE_DEVOPS_ORG:?'AZURE_DEVOPS_ORG environment variable must be set'}"
  PROJECT="${AZURE_DEVOPS_PROJECT:?'AZURE_DEVOPS_PROJECT environment variable must be set'}"
  API_BASE=$(azure_api_base "$ORG" "$PROJECT")
}

# Get GitHub settings from environment (required, except TARGET_BRANCH)
# Sets: GITHUB_OWNER, GITHUB_REPO, TARGET_BRANCH
init_github_defaults() {
  GITHUB_OWNER="${GITHUB_OWNER:?'GITHUB_OWNER environment variable must be set'}"
  GITHUB_REPO="${GITHUB_REPO:?'GITHUB_REPO environment variable must be set'}"
  TARGET_BRANCH="${TARGET_BRANCH:-main}"
}

# Validate HTTP response status code
# Usage: validate_http_status $status $expected "Operation name"
# Returns: 0 if status matches, exits 1 otherwise
validate_http_status() {
  local status="$1"
  local expected="$2"
  local operation="$3"

  if [ "$status" != "$expected" ]; then
    echo "Error: $operation failed. HTTP Status: $status (expected $expected)"
    return 1
  fi
  return 0
}

# Validate JSON file is valid
# Usage: validate_json "/path/to/file.json" "Description"
validate_json() {
  local file="$1"
  local description="${2:-JSON file}"

  if ! jq empty "$file" 2>/dev/null; then
    echo "Error: Invalid JSON in $description"
    cat "$file"
    return 1
  fi
  return 0
}
