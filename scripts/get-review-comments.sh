#!/bin/bash
# Get review comments for a PR, formatted for easy reading
# Usage: get-review-comments.sh <pr-number> [--latest] [--with-ids]
#
# Options:
#   --latest      Only show comments on the latest commit
#   --with-ids    Include comment IDs for replying/resolving

set -euo pipefail

PR_NUMBER="${1:?Usage: get-review-comments.sh <pr-number> [--latest] [--with-ids]}"
shift

LATEST_ONLY=false
WITH_IDS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --latest)
            LATEST_ONLY=true
            shift
            ;;
        --with-ids)
            WITH_IDS=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Get latest commit if --latest flag
SINCE_COMMIT=""
if [[ "$LATEST_ONLY" == "true" ]]; then
    SINCE_COMMIT=$(gh pr view "$PR_NUMBER" --json commits --jq '.commits[-1].oid')
fi

# Get all comments
COMMENTS=$(gh api "repos/:owner/:repo/pulls/$PR_NUMBER/comments" 2>/dev/null)

if [[ -z "$COMMENTS" || "$COMMENTS" == "[]" ]]; then
    echo "No review comments found."
    exit 0
fi

# Format based on options
if [[ "$WITH_IDS" == "true" ]]; then
    echo "$COMMENTS" | jq -r --arg since "$SINCE_COMMIT" '
        .[] |
        select($since == "" or .commit_id >= $since) |
        "=== Comment ID: \(.id) | Node ID: \(.node_id) ===",
        "File: \(.path):\(.line // .original_line // "?")",
        "Priority: \(.body | capture("!\\[(?<p>high|medium|low)\\]") | .p // "unknown")",
        "",
        (.body | gsub("!\\[(high|medium|low)\\]\\([^)]+\\)"; "") | gsub("```suggestion"; "SUGGESTION:") | gsub("```"; "")),
        "",
        "---",
        ""
    '
else
    echo "$COMMENTS" | jq -r --arg since "$SINCE_COMMIT" '
        .[] |
        select($since == "" or .commit_id >= $since) |
        "[\(.path):\(.line // .original_line // "?")]",
        "Priority: \(.body | capture("!\\[(?<p>high|medium|low)\\]") | .p // "unknown")",
        "",
        (.body | gsub("!\\[(high|medium|low)\\]\\([^)]+\\)"; "") | gsub("```suggestion"; "SUGGESTION:") | gsub("```"; "")),
        "",
        "---",
        ""
    '
fi
