---
name: await-verify-changes
description: Use when the user asks to wait for, watch, poll, or follow up on a PR they already reviewed, until the author's fixes are verified and the PR is approved or needs the user's call
arguments: [model, effort]
---

# Await Verify Changes

## Arguments
`/lazy:await-verify-changes <model> <effort>`, both optional.
- model `$0`: opus (default), sonnet, haiku, fable. Empty or unknown → opus.
- effort `$1`: medium, high (default), xhigh. Empty or unknown → high.
Verifier agent: `subagent_type: lazy:await-verify-changes-verifier-<effort>` with `model: <model>`.
State the resolved pair once on the first tick, then never again.

## Overview
Watch one PR after a review. When the author pushes fixes or re-requests
review, verify every finding with the verifier agent. Approve when all is
ready. Message the user only on approval or when their call is needed.
Stay silent otherwise.

## Setup (first tick)
1. Record: PR number, head SHA, the open findings (own review comments +
   unresolved threads). This list is the checklist for every later tick.
2. Run under /loop dynamic pacing. Arm a Monitor on the PR if available.
   Fallback heartbeat: ScheduleWakeup 1200–1800s.

## Each tick
1. Fetch head SHA, review requests, and comments since the last tick.
2. Nothing new → `ScheduleWakeup noop:true`. Zero visible text. No notification.
   Re-arm the Monitor only if TaskList shows none running.
3. Something new → verify:
   - Dispatch ONE verifier agent. Give it: the findings list, the diff
     `git diff <lastSha>..<headSha>`, and the author's replies.
   - Read the verdict critically. Spot-check at least one FIXED claim in the
     diff yourself. An agent handed a hypothesis tends to confirm it.
4. Decide:
   - All FIXED, CI green, no new scope, no sensitive change (see below) →
     `gh pr review --approve` with a short body. Resolve the addressed
     threads. PushNotification "PR #N approved". Stop the loop.
   - Any NOT FIXED, UNSURE, new scope, or sensitive change → do NOT approve.
     PushNotification with ONE question. Keep looping silently; a new commit
     or the user's answer resumes the flow.
5. Record the new lastSha and the remaining findings.

## Sensitive change
A change that is hard to reverse after merge, or that can lose data, money,
or access. Default list: persisted state or schema migrations; payment,
billing, or balance logic; auth, permissions, or secrets; public API or wire
contracts; durable jobs that must stay compatible with in-flight runs.
If the project's CLAUDE.md names sensitive areas, that list wins.

## Rules
- Never stop because ticks are quiet. The default "three quiet ticks → stop"
  does not apply. Stop only on approval, on the user's word, or after 48h of
  silence (then notify "stopped watching PR #N").
- Do not invoke a code-review skill for this. Diff + findings only.
- Do not commit or push on the PR branch.
- Match the repo's language and tone rules for GitHub text.

## Red flags — STOP, message the user
- "Probably fine, the author says it is fixed"
- "Only a small extra change, approving anyway"
- The verifier says UNSURE and you want to upgrade it to FIXED
