#!/bin/bash
# Reply to a PR review comment
# Usage: reply-to-comment.sh <pr-number> <comment-id> "reply message"
#
# Comment IDs can be found in the output of get-review-comments.sh

set -euo pipefail

PR_NUMBER="${1:?Usage: reply-to-comment.sh <pr-number> <comment-id> \"reply message\"}"
COMMENT_ID="${2:?Usage: reply-to-comment.sh <pr-number> <comment-id> \"reply message\"}"
REPLY="${3:?Usage: reply-to-comment.sh <pr-number> <comment-id> \"reply message\"}"

# Get repo info
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')

echo "Replying to comment $COMMENT_ID on PR #$PR_NUMBER..."

gh api \
    --method POST \
    "repos/$REPO/pulls/$PR_NUMBER/comments/$COMMENT_ID/replies" \
    -f body="$REPLY"

echo "Reply posted."
