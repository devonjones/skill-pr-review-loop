---
name: pr-review-loop
description: |
  Manage the PR review feedback loop: monitor CI checks, fetch review comments, and iterate on fixes.
  Use when: (1) pushing changes to a PR and waiting for CI/reviews, (2) user says "new reviews available",
  (3) iterating on PR feedback from Gemini Code Assist or other reviewers, (4) monitoring PR status.
---

# PR Review Loop

Streamline the push-review-fix cycle for PRs with automated reviewers like Gemini Code Assist.

## Critical: Be Skeptical of Reviews

**Not all suggestions are good.** Evaluate each review comment critically:

- Does this actually improve the code, or is it pedantic?
- Is this suggestion appropriate for the project's context?
- Would implementing this introduce unnecessary complexity?

**Skip suggestions that are:**
- Platform-specific when not applicable (Windows comments for Linux-only code)
- Overly defensive (excessive null checks, unlikely edge cases)
- Stylistic preferences that don't match project conventions
- Adding documentation for self-explanatory code

When in doubt, ask the user rather than blindly applying changes.

## Diminishing Returns Detection

Track review cycles. After 2-3 iterations, evaluate:
- Are new comments addressing real issues or nitpicks?
- Are we fixing the same type of issue repeatedly?
- Is the reviewer finding fewer/lower-priority issues?

**If reviews feel like bikeshedding, ask the user:** "We've done N review cycles. The remaining feedback seems like diminishing returns (style nits, unlikely edge cases). Ready to merge, or want to address more?"

## Responding to Reviews

Always respond to review comments in GitHub to document decisions:

### Get comments with IDs
```bash
~/.claude/skills/pr-review-loop/scripts/get-review-comments.sh <PR> --with-ids
```

### Reply to a comment (fixed, won't fix, etc.)
```bash
~/.claude/skills/pr-review-loop/scripts/reply-to-comment.sh <PR> <comment-id> "Fixed in abc123"
~/.claude/skills/pr-review-loop/scripts/reply-to-comment.sh <PR> <comment-id> "Won't fix - this is Linux-only"
```

### Resolve/hide a comment thread
```bash
~/.claude/skills/pr-review-loop/scripts/resolve-comment.sh <node-id> RESOLVED
~/.claude/skills/pr-review-loop/scripts/resolve-comment.sh <node-id> OUTDATED
```

**Reply templates:**
- Fixed: "Fixed in [commit]"
- Won't fix: "Won't fix - [reason]"
- Acknowledged but deferred: "Good catch, but out of scope for this PR. Tracking in #issue"

## Autonomous Loop Workflow

For autonomous review loops (when user grants script access):

### 1. Fetch reviews with IDs
```bash
~/.claude/skills/pr-review-loop/scripts/get-review-comments.sh <PR> --latest --with-ids
```

### 2. For each comment: fix or dismiss
- Apply fix locally
- Reply to comment explaining action taken
- Resolve the thread

### 3. Run pre-commit and commit
```bash
pre-commit run --all-files
~/.claude/skills/pr-review-loop/scripts/commit-and-push.sh "fix: description" --trigger-review
```

### 4. Monitor for next review cycle
```bash
~/.claude/skills/pr-review-loop/scripts/watch-pr.sh <PR> &
```

## Scripts

| Script | Purpose |
|--------|---------|
| `commit-and-push.sh "msg" [--trigger-review]` | Commit, push, optionally request review |
| `trigger-review.sh [PR]` | Post `/gemini review` comment to PR |
| `watch-pr.sh <PR>` | Background monitor for CI + review comments |
| `get-review-comments.sh <PR> [--latest] [--with-ids]` | Fetch formatted review comments |
| `summarize-reviews.sh <PR>` | Summary by priority and file |
| `reply-to-comment.sh <PR> <id> "msg"` | Reply to a review comment |
| `resolve-comment.sh <node-id> [reason]` | Resolve/hide a comment thread |

## Permission Setup

To enable autonomous loops, user should grant access:
```
Bash(~/.claude/skills/pr-review-loop/scripts/commit-and-push.sh:*)
Bash(~/.claude/skills/pr-review-loop/scripts/reply-to-comment.sh:*)
Bash(~/.claude/skills/pr-review-loop/scripts/resolve-comment.sh:*)
Bash(~/.claude/skills/pr-review-loop/scripts/trigger-review.sh:*)
```

## Prerequisites

- `gh` CLI authenticated
- `pre-commit` installed globally (`pip install pre-commit`)
- Pre-commit hooks configured in repo (`.pre-commit-config.yaml`)
