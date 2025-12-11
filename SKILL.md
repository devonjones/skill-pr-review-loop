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

**By default, scripts only show unresolved threads.** Use `--all` to include resolved.

Reply to comments and they auto-resolve:
```bash
# Get unresolved comments with IDs
~/.claude/skills/pr-review-loop/scripts/get-review-comments.sh <PR> --with-ids

# Reply (auto-resolves the thread)
~/.claude/skills/pr-review-loop/scripts/reply-to-comment.sh <PR> <comment-id> "Fixed in abc123"

# Use --no-resolve to reply without resolving
~/.claude/skills/pr-review-loop/scripts/reply-to-comment.sh <PR> <comment-id> "Acknowledged" --no-resolve
```

**Reply templates:**
- Fixed: "Fixed in [commit]" or "Fixed - [description]"
- Won't fix: "Won't fix - [reason]"
- Deferred: "Good catch, tracking in #issue"

## Autonomous Loop Workflow

For autonomous review loops (when user grants script access):

### 1. Check for unresolved comments
```bash
~/.claude/skills/pr-review-loop/scripts/summarize-reviews.sh <PR>
~/.claude/skills/pr-review-loop/scripts/get-review-comments.sh <PR> --with-ids
```

### 2. For each unresolved comment
- Evaluate if suggestion is worthwhile
- Apply fix locally OR decide to skip
- Reply explaining action (auto-resolves thread)

### 3. Commit and trigger next review
```bash
pre-commit run --all-files
~/.claude/skills/pr-review-loop/scripts/commit-and-push.sh "fix: description" --trigger-review
```

### 4. Wait for new reviews
```bash
~/.claude/skills/pr-review-loop/scripts/watch-pr.sh <PR> &
```

### 5. Repeat until no unresolved comments or diminishing returns

## Scripts

| Script | Purpose |
|--------|---------|
| `get-review-comments.sh <PR> [--with-ids] [--all]` | Fetch unresolved comments (use --all for resolved too) |
| `summarize-reviews.sh <PR> [--all]` | Summary of unresolved by priority/file |
| `reply-to-comment.sh <PR> <id> "msg" [--no-resolve]` | Reply and auto-resolve thread |
| `commit-and-push.sh "msg" [--trigger-review]` | Commit, push, optionally request review |
| `trigger-review.sh [PR]` | Post `/gemini review` comment to PR |
| `watch-pr.sh <PR>` | Background monitor for CI + review comments |
| `resolve-comment.sh <node-id> [reason]` | Manually resolve a thread |

## Permission Setup

To enable autonomous loops, user should grant access:
```
Bash(~/.claude/skills/pr-review-loop/scripts/commit-and-push.sh:*)
Bash(~/.claude/skills/pr-review-loop/scripts/reply-to-comment.sh:*)
Bash(~/.claude/skills/pr-review-loop/scripts/trigger-review.sh:*)
```

## Prerequisites

- `gh` CLI authenticated
- `pre-commit` installed globally (`pip install pre-commit`)
- Pre-commit hooks configured in repo (`.pre-commit-config.yaml`)
