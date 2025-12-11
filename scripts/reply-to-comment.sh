#!/bin/bash
# Reply to a PR review comment and resolve the thread
# Usage: reply-to-comment.sh <pr-number> <comment-id> "reply message" [--no-resolve]
#
# Comment IDs can be found in the output of get-review-comments.sh --with-ids
# By default, resolves the conversation after replying. Use --no-resolve to skip.

set -euo pipefail

PR_NUMBER="${1:?Usage: reply-to-comment.sh <pr-number> <comment-id> \"reply message\" [--no-resolve]}"
COMMENT_ID="${2:?Usage: reply-to-comment.sh <pr-number> <comment-id> \"reply message\" [--no-resolve]}"
REPLY="${3:?Usage: reply-to-comment.sh <pr-number> <comment-id> \"reply message\" [--no-resolve]}"
NO_RESOLVE="${4:-}"

# Get repo info
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')

echo "Replying to comment $COMMENT_ID on PR #$PR_NUMBER..."

# Post the reply
gh api \
    --method POST \
    "repos/$REPO/pulls/$PR_NUMBER/comments/$COMMENT_ID/replies" \
    -f body="$REPLY" > /dev/null

echo "Reply posted."

# Resolve the thread unless --no-resolve is specified
if [[ "$NO_RESOLVE" != "--no-resolve" ]]; then
    # Get the node_id for the comment to resolve the thread
    NODE_ID=$(gh api "repos/$REPO/pulls/comments/$COMMENT_ID" --jq '.node_id')

    if [[ -n "$NODE_ID" ]]; then
        echo "Resolving thread..."

        # Use GraphQL to resolve the review thread
        # First, we need to get the thread ID from the comment
        THREAD_ID=$(gh api graphql -f query="
            query {
                node(id: \"$NODE_ID\") {
                    ... on PullRequestReviewComment {
                        pullRequestReviewThread {
                            id
                        }
                    }
                }
            }
        " --jq '.data.node.pullRequestReviewThread.id' 2>/dev/null || echo "")

        if [[ -n "$THREAD_ID" && "$THREAD_ID" != "null" ]]; then
            gh api graphql -f query="
                mutation {
                    resolveReviewThread(input: {threadId: \"$THREAD_ID\"}) {
                        thread {
                            isResolved
                        }
                    }
                }
            " > /dev/null 2>&1 && echo "Thread resolved." || echo "Warning: Could not resolve thread."
        else
            echo "Warning: Could not find thread ID to resolve."
        fi
    fi
fi
