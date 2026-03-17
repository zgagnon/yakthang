---
name: yak-sniff-test
description: Does this yak smell right? Use when a shaver reports done and Yakob needs to verify the work matches the brief using a fresh, independent reviewer agent before accepting or pruning the yak.
---

# Adversarial Review

## Overview

The implementer is never the reviewer. When a shaver reports `done:`, spawn a
fresh agent with no knowledge of the shaver's reasoning — only the brief, the
done summary, the notes, and the git evidence. The reviewer either confirms
delivery or surfaces the gap.

## When to Use

Invoke after a shaver signals `done:` on a yak. Use `/adversarial-review <done-yak-id>`.

**Don't skip because:**
- "It's a small change" — small changes are exactly the ones that slip through
- "I read the comments.md myself" — you have anchoring bias from the shaver's narrative
- "We're in a hurry" — that's when errors get accepted silently

## Yakob's Steps

### 1. Read the done yak

```bash
yx show <done-yak-id> --format json
```

Collect:
- `context.md` — the original brief (what was asked)
- `agent-status` — the shaver's done summary
- `comments.md` — the shaver's notes (what changed and where)

### 2. Mark the yak as under review

```bash
echo "in-progress" | yx field <done-yak-id> review-status
```

This shows 🔍 in the yak-map. Then build the reviewer's prompt using the
template below, substituting the data collected in step 1:

```bash
cat <<'EOF' | yx context "review <done-yak-name>"
# Adversarial Review

You are an independent reviewer. You did not do this work. You have no knowledge
of why the implementer made their choices. Your only job is to verify that the
actual state of the codebase matches what was asked for.

## Original Brief (what was asked)

<paste context.md here>

## Shaver's Done Summary (agent-status)

<paste agent-status here>

## Git Evidence

Run to find what changed (do not ask the shaver — derive evidence only from the brief and the diff):

```bash
git log --oneline -10    # find recent commits
git diff HEAD~1          # or the relevant commit hash
```

## Your Task

1. Extract the key deliverables from the original brief. What was explicitly
   promised? What are the acceptance criteria?

2. Check git log and diff to find what was changed. Navigate to those locations.
   Do not use the shaver's reasoning — all evidence must come from the brief
   and the git diff.

3. For each deliverable, independently verify it exists in the actual state of
   the codebase. Check git log, file contents, test output — whatever applies.
   Do not trust the summary. Look at the evidence.

4. Classify every finding using this taxonomy:
   - **patch** — trivially fixable code issue
   - **intent_gap** — spec is incomplete, cannot resolve from existing info
   - **bad_spec** — spec/brief is wrong or ambiguous
   - **defer** — pre-existing issue, not caused by this change
   - **reject** — noise, drop silently

   **Minimum findings mandate:** Surface at least 3 findings. If you find
   fewer, re-analyze. Zero findings is a HALT — do not produce a verdict.

5. Produce a verdict based on your classified findings:
   - `pass: <one-line summary>` — only valid when all findings are `defer` or `reject`
   - `fail: <one-line summary>` — any `patch` or `intent_gap` finding present
   - `needs-info: <what's missing>` — cannot verify without more information

6. Write your verdict:

```bash
echo "pass: <summary>" | yx field <done-yak-id> review-verdict
# OR
echo "fail: <summary>" | yx field <done-yak-id> review-verdict
echo "<detailed findings with file/line evidence>" | yx field <done-yak-id> review-notes
# OR
echo "needs-info: <what's missing>" | yx field <done-yak-id> review-verdict
```

Write `review-notes` only on `fail` or `needs-info`. On `pass`, the one-line
verdict is enough.

## Anti-Patterns

- Do NOT ask the shaver to clarify — verify independently or write `needs-info`
- Do NOT use the shaver's reasoning to justify findings — find your own evidence
- Do NOT accept "it should work" — verify it does work
EOF
```

### 3. Launch the reviewer as a subagent

Use a `general-purpose` subagent, not `yak-box spawn`. Reviewers
are read-only agents that don't need workspace isolation, and subagents avoid
keychain/auth issues, stale sessions, and Zellij tab clutter.

```
Agent tool call:
  subagent_type: "general-purpose"
  description: "Review <done-yak-name>"
  run_in_background: true
  prompt: |
    You are an adversarial reviewer for the "<done-yak-name>" feature.

    ## Original Brief
    <paste context.md>

    ## Shaver's Done Summary
    <paste agent-status>

    ## Your Task
    1. Check git log and diff in <relevant-dir> — derive evidence from the diff,
       not the shaver's reasoning
    2. Verify each acceptance criterion against actual code
    3. Classify every finding: patch / intent_gap / bad_spec / defer / reject
       Surface at least 3 findings; zero findings = HALT, re-analyze
    4. Note which test commands should be run (e.g., go test ./..., cargo test)
       but do NOT run them yourself — Yakob will run tests separately
    5. Report verdict: pass (all findings defer/reject), fail (any patch/intent_gap),
       or needs-info — with file/line evidence
```

### 4. When the subagent returns

**Run the tests yourself.** The subagent cannot run bash commands, so Yakob
must independently verify that tests pass before recording the verdict:

```bash
# Run whatever tests apply to the changed code
cd <relevant-dir> && go test ./...    # or cargo test, npm test, etc.
```

Then parse the verdict from the subagent's response and write it to the yak.

**Always set both `review-status` (for yak-map emoji) and `review-verdict` (detailed findings):**

```bash
# On pass:
echo "pass: <summary>" | yx field <done-yak-id> review-status
echo "pass: <summary>" | yx field <done-yak-id> review-verdict

# On fail:
echo "fail: <summary>" | yx field <done-yak-id> review-status
echo "fail: <summary>" | yx field <done-yak-id> review-verdict
echo "<detailed findings>" | yx field <done-yak-id> review-notes

# On needs-info:
echo "in-progress" | yx field <done-yak-id> review-status
echo "needs-info: <what's missing>" | yx field <done-yak-id> review-verdict
```

`review-status` drives the yak-map emoji (🔍 ✅ ❌). `review-verdict` holds the full text.

## Reading Results

The yak-map shows the emoji (🔍 ✅ ❌). For details:

```bash
yx field --show <done-yak-id> review-verdict
```

| Verdict | Emoji | What to do |
|---------|-------|-----------|
| `pass:` | ✅ | Proceed — prune or accept as usual |
| `fail:` | ❌ | Read `review-notes`, create a follow-up sub-yak |
| `needs-info:` | 🔍 | Read the notes, clarify the brief, re-review |

On `fail`, create a follow-up sub-yak with the reviewer's findings as context:

```bash
yx add "fix <done-yak-name>" --under <done-yak-id>
# Pipe the review-notes as context for the fix
yx field --show <done-yak-id> review-notes | yx context "fix <done-yak-name>"
```

Sub-yaks are **only** created on fail — not for every review.

## Anti-Patterns

- **Shaver reviews their own work** — no anchoring allowed; fresh agent only
- **Passing reviewer findings to a re-review** — starts the next review clean
- **Skipping because "it's a small change"** — that's exactly the judgment this gate validates
- **Reading comments.md and deciding yourself** — you have Yakob bias; spawn the reviewer

## Why Subagents, Not yak-box spawn

Reviewers are read-only by design. They don't edit files, don't need workspace
isolation, and don't need their own Zellij tab. Subagents:

- Inherit Yakob's auth (no keychain issues)
- Leave no stale sessions or `assigned-to` files
- Don't count against the WIP limit (they're Yakob's work, not independent shavers)
- Run in background and notify on completion

**Do not use `yak-box spawn` for reviews.** That path has known issues with
keychain access, tab cleanup, and assignment paperwork — all overhead with
zero benefit for a read-only task. When spawning shavers for implementation
work, use `--skill .claude/skills/yak-shaving-handbook` (see yakob.md).

## Quick Reference

| Step | Command |
|------|---------|
| Read done yak | `yx show <id> --format json` |
| Mark under review | `echo "in-progress" \| yx field <id> review-status` |
| Launch reviewer | Agent tool: `general-purpose`, `run_in_background: true` |
| Record verdict | `echo "pass: ..." \| yx field <id> review-status` + `review-verdict` |
| On fail: sub-yak | `yx add "fix <name>" --under <id>` |
| Read failure detail | `yx field --show <id> review-notes` |
