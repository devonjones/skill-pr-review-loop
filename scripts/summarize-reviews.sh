#!/bin/bash
# Summarize review comments by priority and file
# Usage: summarize-reviews.sh <pr-number> [repo]

set -euo pipefail

PR_NUMBER="${1:?Usage: summarize-reviews.sh <pr-number> [repo]}"
REPO="${2:-}"

REPO_FLAG=""
if [[ -n "$REPO" ]]; then
    REPO_FLAG="-R $REPO"
fi

echo "=== PR #$PR_NUMBER Review Summary ==="
echo ""

# Get comments
COMMENTS=$(gh api $REPO_FLAG repos/:owner/:repo/pulls/$PR_NUMBER/comments 2>/dev/null)

if [[ -z "$COMMENTS" || "$COMMENTS" == "[]" ]]; then
    echo "No review comments."
    exit 0
fi

# Count by priority
echo "## By Priority"
echo "$COMMENTS" | jq -r '
    group_by(.body | capture("!\\[(?<p>high|medium|low)\\]") | .p // "unknown") |
    .[] |
    "- \(.[0].body | capture("!\\[(?<p>high|medium|low)\\]") | .p // "unknown"): \(length) comments"
'
echo ""

# Group by file
echo "## By File"
echo "$COMMENTS" | jq -r '
    group_by(.path) |
    .[] |
    "- \(.[0].path): \(length) comments"
'
echo ""

# List high priority items
echo "## High Priority Items"
echo "$COMMENTS" | jq -r '
    .[] |
    select(.body | test("!\\[high\\]")) |
    "- [\(.path):\(.line // "?")] \(.body | split("\n")[0] | gsub("!\\[high\\]\\([^)]+\\)"; "") | .[0:80])"
'
