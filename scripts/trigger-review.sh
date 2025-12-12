#!/bin/bash
# Trigger a code review on a PR (Gemini with Claude fallback)
# Usage: trigger-review.sh [pr-number] [--claude]
#
# By default, triggers Gemini Code Assist. If Gemini is rate-limited,
# outputs instructions for Claude fallback.
#
# Options:
#   --claude    Skip Gemini and use Claude agent directly

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PR_NUMBER=""
USE_CLAUDE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --claude)
            USE_CLAUDE=true
            shift
            ;;
        *)
            if [[ -z "$PR_NUMBER" ]]; then
                PR_NUMBER="$1"
            fi
            shift
            ;;
    esac
done

# Get PR number if not provided
if [[ -z "$PR_NUMBER" ]]; then
    PR_NUMBER=$(gh pr view --json number --jq '.number' 2>/dev/null || echo "")
fi

if [[ -z "$PR_NUMBER" ]]; then
    echo "Error: Could not determine PR number. Provide it as argument or run from a branch with an open PR."
    exit 1
fi

# If --claude flag, go directly to Claude
if [[ "$USE_CLAUDE" == "true" ]]; then
    echo "Using Claude agent for code review..."
    exec "$SCRIPT_DIR/claude-review.sh" "$PR_NUMBER"
fi

# Check if Gemini is already rate-limited before triggering
if ! "$SCRIPT_DIR/check-gemini-quota.sh" "$PR_NUMBER" > /dev/null 2>&1; then
    echo "!!! Gemini Code Assist is rate-limited !!!"
    echo ""
    echo "Options:"
    echo "  1. Wait up to 24 hours for quota to reset"
    echo "  2. Use Claude agent for code review:"
    echo ""
    echo "     ~/.claude/skills/pr-review-loop/scripts/claude-review.sh $PR_NUMBER"
    echo ""
    echo "  Or re-run with --claude flag:"
    echo ""
    echo "     ~/.claude/skills/pr-review-loop/scripts/trigger-review.sh $PR_NUMBER --claude"
    echo ""
    exit 1
fi

echo "Triggering Gemini review on PR #$PR_NUMBER..."
gh pr comment "$PR_NUMBER" --body "/gemini review"
echo "Review requested. Comments typically arrive in 1-2 minutes."
echo ""
echo "If Gemini is rate-limited, use Claude fallback:"
echo "  ~/.claude/skills/pr-review-loop/scripts/claude-review.sh $PR_NUMBER"
