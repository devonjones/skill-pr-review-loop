#!/bin/bash
# Summarize review comments by priority and file
# Usage: summarize-reviews.sh <pr-number> [--all]
#
# Options:
#   --all    Include resolved threads (default: unresolved only)

set -euo pipefail

PR_NUMBER="${1:?Usage: summarize-reviews.sh <pr-number> [--all]}"
INCLUDE_RESOLVED=false

for arg in "$@"; do
    if [[ "$arg" == "--all" ]]; then
        INCLUDE_RESOLVED=true
    fi
done

# Get repo info
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

echo "=== PR #$PR_NUMBER Review Summary ==="
echo ""

# Use GraphQL to get review threads with resolution status
QUERY='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 1) {
            nodes {
              path
              line
              originalLine
              body
            }
          }
        }
      }
    }
  }
}
'

RESULT=$(gh api graphql -f query="$QUERY" -f owner="$OWNER" -f repo="$REPO_NAME" -F pr="$PR_NUMBER" 2>/dev/null)

if [[ -z "$RESULT" ]]; then
    echo "No review comments."
    exit 0
fi

# Extract comments based on resolution filter
COMMENTS=$(echo "$RESULT" | jq --argjson resolved "$INCLUDE_RESOLVED" '
    [.data.repository.pullRequest.reviewThreads.nodes[] |
     select($resolved or .isResolved == false) |
     .comments.nodes[0] |
     select(. != null)]
')

if [[ "$COMMENTS" == "[]" ]]; then
    if [[ "$INCLUDE_RESOLVED" == "false" ]]; then
        echo "No unresolved review comments."
    else
        echo "No review comments."
    fi
    exit 0
fi

# Priority detection function supports multiple bot formats:
# - Gemini: ![critical], ![high], ![medium], ![low]
# - Cursor: <!-- **High Severity** -->, <!-- **Critical Severity** -->
# - Claude: **Critical**, ### Critical Issues, CRITICAL
PRIORITY_DETECT='
def detect_priority:
    # Gemini format: ![critical], ![high], ![medium], ![low]
    if test("!\\[critical\\]"; "i") then "critical"
    elif test("!\\[high\\]"; "i") then "high"
    elif test("!\\[medium\\]"; "i") then "medium"
    elif test("!\\[low\\]"; "i") then "low"
    # Cursor format: <!-- **High Severity** -->
    elif test("Critical Severity"; "i") then "critical"
    elif test("High Severity"; "i") then "high"
    elif test("Medium Severity"; "i") then "medium"
    elif test("Low Severity"; "i") then "low"
    # Claude/general markdown: **Critical**, ### Critical, CRITICAL:
    elif test("\\*\\*Critical"; "i") or test("### Critical"; "i") or test("CRITICAL:"; "") then "critical"
    elif test("\\*\\*High"; "i") or test("### High"; "i") or test("HIGH:"; "") then "high"
    elif test("\\*\\*Medium"; "i") or test("### Medium"; "i") or test("MEDIUM:"; "") then "medium"
    elif test("\\*\\*Low"; "i") or test("### Low"; "i") or test("LOW:"; "") then "low"
    # Cursor Bug headers
    elif test("### Bug:"; "") then "high"
    elif test("### Issue:"; "") then "medium"
    elif test("### Suggestion:"; "") then "low"
    else "unknown"
    end;
'

# Count by priority
echo "## By Priority"
echo "$COMMENTS" | jq -r "$PRIORITY_DETECT"'
    [.[] | . + {priority: (.body | detect_priority)}] |
    group_by(.priority) |
    sort_by(.[0].priority | if . == "critical" then 0 elif . == "high" then 1 elif . == "medium" then 2 elif . == "low" then 3 else 4 end) |
    .[] |
    "- \(.[0].priority): \(length) comment(s)"
'
echo ""

# Group by file
echo "## By File"
echo "$COMMENTS" | jq -r '
    group_by(.path) |
    .[] |
    "- \(.[0].path): \(length) comment(s)"
'
echo ""

# List critical and high priority items
echo "## Critical/High Priority Items"
echo "$COMMENTS" | jq -r "$PRIORITY_DETECT"'
    .[] |
    select((.body | detect_priority) == "critical" or (.body | detect_priority) == "high") |
    "- [\(.path):\(.line // .originalLine // "?")] [\(.body | detect_priority)] \(.body | split("\n")[0] | gsub("!\\[(critical|high|medium|low)\\]\\([^)]+\\)"; "") | .[0:80])"
'
