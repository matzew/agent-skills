#!/bin/bash
# Block gh write operations and require manual user confirmation.
# Fires as a PreToolUse hook for Bash commands.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# gh write operations that must not run without explicit user approval
WRITE_PATTERNS=(
  "gh pr comment"
  "gh pr create"
  "gh pr merge"
  "gh pr close"
  "gh pr ready"
  "gh pr draft"
  "gh pr edit"
  "gh pr review"
  "gh issue comment"
  "gh issue create"
  "gh issue close"
  "gh issue edit"
  "gh release create"
  "gh release delete"
  "gh release edit"
  "gh release upload"
  "gh repo create"
  "gh repo delete"
  "gh repo edit"
  "gh gist create"
  "gh gist edit"
  "gh gist delete"
  "gh label create"
  "gh label delete"
  "gh label edit"
  "gh milestone create"
  "gh milestone delete"
  "gh milestone edit"
  "gh secret set"
  "gh secret delete"
  "gh variable set"
  "gh variable delete"
  "gh workflow run"
  "gh workflow disable"
  "gh workflow enable"
  "git push"
)

for pattern in "${WRITE_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "(^|[|;&]| )(sudo )?$pattern"; then
    echo "Blocked GitHub write operation: requires your explicit approval before running." >&2
    echo "Command was: $COMMAND" >&2
    exit 2
  fi
done

exit 0
