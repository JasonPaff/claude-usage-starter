#!/bin/bash
# stream-processor.sh
# Processes Claude Code stream-json output for Azure DevOps pipeline logs
#
# Features:
# - Streams all output in real-time to stdout
# - Detects MILESTONE: markers and emits Azure DevOps logging commands
# - Preserves text content for downstream grep/detection
# - Handles tool_use events for visibility
#
# Usage: claude --output-format stream-json ... | ./stream-processor.sh | tee output.txt

set -o pipefail

# Emit Azure DevOps milestone markers based on milestone type
emit_milestone() {
  local milestone="$1"

  case "$milestone" in
    # Quick-Fix milestones
    COMPLEXITY_ASSESSED_TRIVIAL)
      echo "##[section]Complexity Assessment: TRIVIAL - Proceeding with fix"
      ;;
    COMPLEXITY_ASSESSED_COMPLEX)
      echo "##vso[task.logissue type=warning]Complexity Assessment: COMPLEX - Bailing out"
      ;;
    FIX_APPLIED)
      echo "##[section]Fix Applied - Running validation"
      ;;
    VALIDATION_COMPLETE)
      echo "##[section]Validation Complete - All checks passed"
      ;;
    QUICK_FIX_SUCCESS)
      echo "##[section]Quick Fix Completed Successfully"
      ;;

    # Plan-Feature milestones
    STEP_1_COMPLETE)
      echo "##[section]Step 1/3 Complete: Feature Refinement"
      ;;
    STEP_2_COMPLETE)
      echo "##[section]Step 2/3 Complete: File Discovery"
      ;;
    STEP_3_COMPLETE)
      echo "##[section]Step 3/3 Complete: Implementation Planning"
      ;;
    PLAN_FEATURE_SUCCESS)
      echo "##[section]Plan-Feature Completed Successfully"
      ;;

    # Implement-Plan phase milestones
    PHASE_1_COMPLETE)
      echo "##[section]Phase 1/5 Complete: Pre-Implementation Checks"
      ;;
    PHASE_2_COMPLETE)
      echo "##[section]Phase 2/5 Complete: Setup and Routing"
      ;;
    PHASE_3_START)
      echo "##[section]Phase 3/5 Starting: Step Execution"
      ;;
    PHASE_4_START)
      echo "##[section]Phase 4/5 Starting: Quality Gates"
      ;;
    PHASE_4_COMPLETE)
      echo "##[section]Phase 4/5 Complete: Quality Gates"
      ;;
    PHASE_5_COMPLETE)
      echo "##[section]Phase 5/5 Complete: Summary"
      ;;
    IMPLEMENT_PLAN_SUCCESS)
      echo "##[section]Implementation Completed Successfully"
      ;;

    # Specialist agent milestones (format: SPECIALIST_START:type:Step N)
    SPECIALIST_START:*)
      local spec_info="${milestone#SPECIALIST_START:}"
      echo "##[group]Launching specialist: $spec_info"
      ;;
    SPECIALIST_END:*)
      local spec_info="${milestone#SPECIALIST_END:}"
      echo "##[endgroup]"
      echo "##[section]Specialist completed: $spec_info"
      ;;

    # Quality gate results (format: QUALITY_GATE:name:PASS or QUALITY_GATE:name:FAIL)
    QUALITY_GATE:*:PASS)
      local gate="${milestone#QUALITY_GATE:}"
      gate="${gate%:PASS}"
      echo "##[section]Quality Gate PASSED: $gate"
      ;;
    QUALITY_GATE:*:FAIL)
      local gate="${milestone#QUALITY_GATE:}"
      gate="${gate%:FAIL}"
      echo "##vso[task.logissue type=error]Quality Gate FAILED: $gate"
      ;;

    *)
      # Unknown milestone - still log it
      echo "##[section]Milestone: $milestone"
      ;;
  esac
}

# Extract text content from various JSON structures
extract_text_from_json() {
  local json="$1"
  # Handle different JSON structures from stream-json
  echo "$json" | jq -r '
    .message.content[0].text //
    .content[0].text //
    .content //
    .text //
    empty
  ' 2>/dev/null
}

# Main processing loop
while IFS= read -r line; do
  # Skip empty lines
  [[ -z "$line" ]] && continue

  # Try to parse as JSON and extract event type
  EVENT_TYPE=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)

  # If not valid JSON or no type, pass through as-is
  if [[ -z "$EVENT_TYPE" ]]; then
    echo "$line"
    continue
  fi

  case "$EVENT_TYPE" in
    "assistant")
      # Extract and output the text content
      TEXT=$(extract_text_from_json "$line")
      if [[ -n "$TEXT" ]]; then
        echo "$TEXT"

        # Check for milestone markers in the text
        if [[ "$TEXT" =~ MILESTONE:([A-Za-z0-9_:]+) ]]; then
          emit_milestone "${BASH_REMATCH[1]}"
        fi

        # Check for bailout (backward compatibility with existing grep detection)
        if echo "$TEXT" | grep -q "Quick Fix Not Appropriate"; then
          echo "##vso[task.logissue type=warning]Quick Fix Not Appropriate - Issue Too Complex"
        fi
      fi
      ;;

    "tool_use")
      # Show tool invocations
      TOOL_NAME=$(echo "$line" | jq -r '.name // "unknown"' 2>/dev/null)
      echo "##[command]Tool: $TOOL_NAME"
      ;;

    "tool_result")
      # Extract tool result for display (truncate if very long)
      RESULT=$(echo "$line" | jq -r '.content // empty' 2>/dev/null)
      if [[ -n "$RESULT" ]]; then
        if [[ ${#RESULT} -gt 1000 ]]; then
          echo "${RESULT:0:1000}... (truncated)"
        else
          echo "$RESULT"
        fi
      fi
      ;;

    "system")
      # System messages - pass through
      CONTENT=$(echo "$line" | jq -r '.message // .content // empty' 2>/dev/null)
      [[ -n "$CONTENT" ]] && echo "[System] $CONTENT"
      ;;

    "result")
      # Final result
      echo "##[section]Claude Code Execution Complete"
      RESULT=$(echo "$line" | jq -r '.result // empty' 2>/dev/null)
      [[ -n "$RESULT" ]] && echo "$RESULT"
      ;;

    *)
      # Pass through unknown event types
      echo "$line"
      ;;
  esac
done

echo "##[section]Stream Processing Complete"
