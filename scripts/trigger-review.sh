#!/bin/bash
# Trigger a Gemini Code Assist review on a PR
# Usage: trigger-review.sh [pr-number]
#
# If no PR number provided, uses the PR for the current branch

set -euo pipefail

PR_NUMBER="${1:-}"

if [[ -z "$PR_NUMBER" ]]; then
    PR_NUMBER=$(gh pr view --json number --jq '.number' 2>/dev/null || echo "")
fi

if [[ -z "$PR_NUMBER" ]]; then
    echo "Error: Could not determine PR number. Provide it as argument or run from a branch with an open PR."
    exit 1
fi

echo "Triggering Gemini review on PR #$PR_NUMBER..."
gh pr comment "$PR_NUMBER" --body "/gemini review"
echo "Review requested. Comments typically arrive in 1-2 minutes."
