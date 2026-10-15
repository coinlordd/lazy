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
State the resolved pair once, in the WATCHING headline, then never again.

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
Rebuild it before each verify: the poll does not report the user's own
comments. The state file says only which items are already verified. It
never adds items.

## Setup (first tick)
1. Record: PR number, head SHA (`lastSha`), the findings list.
2. If a review from the user is already requested, verify now (below).
3. Poll once from the user's checkout to record the baseline:
   `bash <skill dir>/monitor.sh <pr> <scratchpad>/await-pr<pr>/monitor`.
   The first run emits nothing. Nothing keeps running between ticks: no
   background task, no detached process, no Monitor tool. Closing the
   session ends the watch.
4. Run under /loop dynamic pacing: `ScheduleWakeup 1200s`. Each tick is
   that same poll command, ONE Bash call. Its stdout holds the events.
   The harness fires an overdue timer as soon as the Mac wakes from sleep,
   so the first tick after the laptop opens polls at once.
5. Write the state file (see below).

## Events and their reaction
| Event | Reaction |
|---|---|
| `NEW_COMMIT <sha>` | Verify, then decide. |
| `NEW_COMMENT` / `NEW_INLINE` by the author | Answer to an open item → update that item. Question to the user → ACTION message. |
| `NEW_COMMENT` / `NEW_INLINE` by someone else | Note it. The findings list does not change. |
| `NEW_REVIEW` | By the author: same as a comment. By someone else: note it. |
| `REVIEW_REQUESTED` | Author says done. Head moved since `verifiedSha` → verify all open items, then decide. Head unchanged and an ACTION is open → silent, the user already has the question. Head unchanged and no ACTION open → ACTION: "author says done, items X untouched". |
| `CHECKS pass` / `CHECKS fail` | If a decide waits on CI, decide now. Else note it. |
| `PR_STATE MERGED` / `CLOSED` | Send the STOPPED message. Stop the loop. |
| No output (or exit 1) | `ScheduleWakeup noop:true`. Your whole reply is the poll call and that call. Zero visible text. |

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
  user started. Send the APPROVED message. Stop the loop.
- **Ask the user**: any NOT FIXED, UNSURE, new scope, sensitive change, a
  question from the author, or CI `fail` when all else is ready → do NOT
  approve. Send the ACTION message with ONE question. Keep looping
  silently.
- **Silent wait**: CI `pending`; or the commit is clean but open items are
  untouched and the author has not replied to them → record, no
  notification, keep looping.

## Messages (the only visible text in the whole loop)
The terminal host shows the first line of the final reply as a desktop
notification, cut at about 90 characters. So line 1 is always a headline:
an icon, a status word, the PR, and the point. Under 90 characters. No
prose before it. Then a blank line, then the body. Four messages exist:

1. First tick only:
   `👀 WATCHING PR #N: <k> open items · <model>/<effort>`
   Body: the numbered findings list.
2. The user must decide:
   `🔴 ACTION PR #N: <the one question>`
   Body: the problem in simple numbered steps, so the user can judge
   without opening the PR:
   ```
   🔴 ACTION PR #1273: approve now, or wait for the PR body fix?

   1. Han pushed 2 commits. Items A and B are fixed. CI green.
   2. The PR body still describes the old cloid aggregate. Stale, not wrong.
   3. The change touches fills/journal. That is on the sensitive list.
   Options: (a) approve now, (b) ask Han to fix the body first.
   ```
   For NOT FIXED or UNSURE: one step per item, what the verifier saw,
   and where (file, one line of context).
3. Approved:
   `✅ APPROVED PR #N`
   Body: the verified items, CI state, verifier model+effort.
4. Stopped:
   `⏹ STOPPED PR #N: <merged | closed | 48h quiet | your word>`

Never send: progress ("checking whether the head changed"), reminders
("waiting on your decision", "still watching"), or "nothing new". A
quiet tick has zero text. One ACTION per open question; send it again
only with new information, and then say what is new in step 1.
Also call PushNotification with the headline. It is skipped while the
user is at the terminal; that is fine, the headline is still there.

## State file
Keep `<scratchpad>/await-pr<pr>/state.md`: `lastSha`, `verifiedSha` (head
at the last verify), the findings with their status, the open ACTION if
any, and the time of the last PR event.
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
  after the last PR event (then send the STOPPED message).
- Do not invoke a code-review skill for this. Diff + findings only.
- Do not commit, push, or check out anything in the user's worktree.
- Match the repo's language and tone rules for GitHub text.

## Red flags — STOP, message the user
- A quiet tick with any visible text ("PR unchanged, still watching").
  That is a silence violation, not an update.
- "Probably fine, the author says it is fixed"
- "Only a small extra change, approving anyway"
- The verifier says UNSURE and you want to upgrade it to FIXED
