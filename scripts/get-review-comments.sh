#!/bin/bash
# Get review comments for a PR, formatted for easy reading
# Usage: get-review-comments.sh <pr-number> [--latest] [--with-ids] [--all]
#
# Options:
#   --latest      Only show comments on the latest commit
#   --with-ids    Include comment IDs for replying/resolving
#   --all         Include resolved threads (default: unresolved only)

set -euo pipefail

PR_NUMBER="${1:?Usage: get-review-comments.sh <pr-number> [--latest] [--with-ids] [--all]}"
shift

LATEST_ONLY=false
WITH_IDS=false
INCLUDE_RESOLVED=false

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
        --all)
            INCLUDE_RESOLVED=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Get repo info
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

# Get latest commit if --latest flag
SINCE_COMMIT=""
if [[ "$LATEST_ONLY" == "true" ]]; then
    SINCE_COMMIT=$(gh pr view "$PR_NUMBER" --json commits --jq '.commits[-1].oid')
fi

# Use GraphQL to get review threads with resolution status
QUERY='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 10) {
            nodes {
              id
              databaseId
              path
              line
              originalLine
              body
              commit {
                oid
              }
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
    echo "No review comments found."
    exit 0
fi

# Process and filter the results
echo "$RESULT" | jq -r --arg since "$SINCE_COMMIT" --argjson resolved "$INCLUDE_RESOLVED" --argjson withIds "$WITH_IDS" '
    .data.repository.pullRequest.reviewThreads.nodes[] |
    select($resolved or .isResolved == false) |
    .comments.nodes[0] as $comment |
    select($comment != null) |
    select($since == "" or ($comment.commit.oid // "") >= $since) |
    if $withIds then
        "=== Comment ID: \($comment.databaseId) | Node ID: \($comment.id) ===",
        "File: \($comment.path):\($comment.line // $comment.originalLine // "?")",
        "Priority: \($comment.body | capture("!\\[(?<p>high|medium|low)\\]") | .p // "unknown")",
        "",
        ($comment.body | gsub("!\\[(high|medium|low)\\]\\([^)]+\\)"; "") | gsub("```suggestion"; "SUGGESTION:") | gsub("```"; "")),
        "",
        "---",
        ""
    else
        "[\($comment.path):\($comment.line // $comment.originalLine // "?")]",
        "Priority: \($comment.body | capture("!\\[(?<p>high|medium|low)\\]") | .p // "unknown")",
        "",
        ($comment.body | gsub("!\\[(high|medium|low)\\]\\([^)]+\\)"; "") | gsub("```suggestion"; "SUGGESTION:") | gsub("```"; "")),
        "",
        "---",
        ""
    end
'
