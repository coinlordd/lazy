---
name: await-verify-changes
description: Use when the user asks to wait for, watch, poll, or follow up on a PR they already reviewed, until the author's fixes are verified and the PR is approved or needs the user's call
arguments: [model, effort]
---

# Await Verify Changes

## Arguments
Invoked as `/lazy:await-verify-changes <model> <effort>`, both optional.
Resolved values for this run: model=`$0`, effort=`$1`.
- model: opus (default), sonnet, haiku, fable. Empty or unknown → opus.
- effort: medium, high (default), xhigh. Empty or unknown → high.
Verifier: `subagent_type: lazy:await-verify-changes-verifier-<effort>`, `model: <model>`.
State the resolved pair once on the first tick, then never again.

## Overview
Watch one PR after a review. When the author pushes fixes or re-requests
review, verify them with the verifier agent. Approve when all is ready.
Message the user only on approval or when their call is needed.
Stay silent otherwise.

## Findings list (the checklist)
Build it from the PR, from the user's own words only:
1. the user's CHANGES_REQUESTED review body
2. the user's later PR comments and review comments
3. unresolved threads the user started
Rebuild it before each verify: the watcher does not report the user's own
comments. The state file says only which items are already verified. It
never adds items.

## Setup (first tick)
1. Record: PR number, head SHA (`lastSha`), the findings list.
2. If a review from the user is already requested, verify now (below).
3. Arm the watcher as a background Bash task, from the user's checkout:
   `AWAIT_VERIFY_ONCE=1 bash <skill dir>/monitor.sh <pr> <scratchpad>/await-pr<pr>/monitor`,
   `run_in_background: true`, `timeout: 7200000`. It polls GitHub every 5
   minutes and exits after the first poll with events. Its stdout holds the
   events. Do not use the Monitor tool: it caps at 30 minutes and costs a
   turn per expiry. Re-arm with the same state dir after every exit, only if
   TaskList shows none running.
4. Run under /loop dynamic pacing. Fallback heartbeat: ScheduleWakeup 3600s.
5. Write the state file (see below).

## Events and their reaction
| Event | Reaction |
|---|---|
| `NEW_COMMIT <sha>` | Verify, then decide. |
| `NEW_COMMENT` / `NEW_INLINE` by the author | Answer to an open item → update that item. Question to the user → notify. |
| `NEW_COMMENT` / `NEW_INLINE` by someone else | Note it. The findings list does not change. |
| `NEW_REVIEW` | By the author: same as a comment. By someone else: note it. |
| `REVIEW_REQUESTED` | Author says done. Verify all open items at head, then decide. |
| `CHECKS pass` / `CHECKS fail` | If a decide waits on CI, decide now. Else note it. |
| `PR_STATE MERGED` / `CLOSED` | Stop the loop. Notify once. |
| Watcher timed out, or nothing | Re-arm if needed. `ScheduleWakeup noop:true`. Your whole reply is that call. Zero visible text. |

## Verify
1. `git fetch origin pull/<pr>/head <base>`.
2. Select the author's own commits:
   - `lastSha` is an ancestor of head (`git merge-base --is-ancestor`) →
     `git log --first-parent --no-merges <lastSha>..<headSha>`. This skips
     merges of the base and the base commits they bring in.
   - Else (force-push or rebase) → the range is `<merge-base>..<headSha>`
     against the base, and every open item is in scope.
   - No author commits (only a base merge) → set `lastSha`, stay silent.
3. Dispatch ONE verifier agent with `verifier-prompt.md`, filled in.
   Verdicts hold for the code at `headSha`. The per-commit diffs only show
   where to look: a later commit can undo an earlier fix.
4. Read the verdict critically. Spot-check one FIXED claim in the diff
   yourself. An agent handed a hypothesis tends to confirm it.

## Decide (three outcomes)
- **Approve**: every item FIXED, CI `pass` (`gh pr checks`), no new scope,
  no sensitive change → `gh pr review --approve` with a body that names the
  verified items and the verifier model+effort. Resolve only threads the
  user started. PushNotification "PR #N approved". Stop the loop.
- **Ask the user**: any NOT FIXED, UNSURE, new scope, sensitive change, a
  question from the author, or CI `fail` when all else is ready → do NOT
  approve. PushNotification with ONE question. One notification per open
  question; repeat only with new information. Keep looping silently.
- **Silent wait**: CI `pending`; or the commit is clean but open items are
  untouched and the author has not replied to them → record, no
  notification, keep looping.

## State file
Keep `<scratchpad>/await-pr<pr>/state.md`: `lastSha`, the findings with
their status, the questions already sent, and the time of the last PR event.
Write it after every tick that changed something. A context compaction
must not lose the checklist. Do not put this in project memory.

## Sensitive change
A change that is hard to reverse after merge, or that can lose data, money,
or access. Default list: persisted state or schema migrations; payment,
billing, or balance logic; auth, permissions, or secrets; public API or wire
contracts; durable jobs that must stay compatible with in-flight runs.
If the project's CLAUDE.md names sensitive areas, that list wins.

## Rules
- Never stop because ticks are quiet. The default "three quiet ticks → stop"
  does not apply. Stop only on approval, PR close, the user's word, or 48h
  after the last PR event (then notify "stopped watching PR #N").
- Do not invoke a code-review skill for this. Diff + findings only.
- Do not commit, push, or check out anything in the user's worktree.
- Match the repo's language and tone rules for GitHub text.

## Red flags — STOP, message the user
- A quiet tick with any visible text ("PR unchanged, still watching").
  That is a silence violation, not an update.
- "Probably fine, the author says it is fixed"
- "Only a small extra change, approving anyway"
- The verifier says UNSURE and you want to upgrade it to FIXED
