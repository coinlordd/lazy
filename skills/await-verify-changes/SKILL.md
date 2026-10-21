---
name: await-verify-changes
description: Use when the user asks to wait for, watch, poll, or follow up on a PR they already reviewed, until the author's fixes are verified and the PR is approved or needs the user's call
arguments: [model, effort, minutes]
---

# Await Verify Changes

## Arguments
Invoked as `/lazy:await-verify-changes <model> <effort> <minutes>`, all
optional. Resolved values for this run: model=`$0`, effort=`$1`,
minutes=`$2`.
- model: opus (default), sonnet, haiku, fable. Empty or unknown → opus.
- effort: medium, high (default), xhigh. Empty or unknown → high.
- minutes: poll interval, 1 to 60. Empty or invalid → 20.
- `stop` as the first argument: run `bash <skill dir>/watch.sh stop <state dir>`
  for the PR the user names, say "stopped", done.
Verifier: `subagent_type: lazy:await-verify-changes-verifier-<effort>`, `model: <model>`.

## Overview
Watch one PR after a review. The session only sets the watch up. A launchd
job polls GitHub every `<minutes>` with no model involved. Only when the
poll finds an event does it start one headless Claude turn (the "Event
tick" below) that verifies, decides, and writes its reply to `log.md`.
The session that set the watch up relays that reply into its own chat
(the "Relay" below). The chat is the primary channel; the macOS
notification is the fallback for when the session is closed. Quiet polls
produce nothing: no turn, no text, no notification.

## Findings list (the checklist)
Build it from the PR, from the user's own words only:
1. the user's CHANGES_REQUESTED review body
2. the user's later PR comments and review comments
3. unresolved threads the user started
Rebuild it before each verify: the poll does not report the user's own
comments. The state file says only which items are already verified. It
never adds items.

## Setup (in the session)
1. Record: PR number, head SHA (`lastSha`), the findings list.
2. If a review from the user is already requested, verify now (below).
3. From the user's checkout: `bash <skill dir>/watch.sh install <pr> <minutes>`.
   It records the baseline, installs the launchd job, and prints the state
   dir. No loop, no ScheduleWakeup, no Monitor tool in this session. The
   watch survives closing the session. If it prints a `NOTIFICATIONS:` line
   on stderr, repeat that line to the user in the WATCHING message.
4. Write the state file (see below), including model and effort.
5. Arm the relay (below). Mandatory: without it the tick's reply never
   reaches this chat.
6. Reply with the WATCHING message. The session is done until the relay
   fires.

## Relay (in the session)
The launchd tick cannot write into the chat. The session waits for it:
`bash <skill dir>/relay.sh <state dir> <lines in log.md now>` through Bash
with `run_in_background` and `timeout` 7200000. It prints nothing until
`log.md` gains a headline line (🔴 ✅ ⏹) past the given line, then prints
that entry and exits.
- It fired → post the printed entry in the chat as is, headline first. After
  🔴 ACTION, arm it again from the new line count. After ✅ or ⏹, do not.
- It timed out with no event → arm it again from the same line, with no
  text in the chat. A quiet wait is silent.
- It printed `⏹ WATCH GONE` → the launchd job is gone without a reply in
  `log.md` (stopped by hand, or a poll crash). Tell the user in one line.

## Event tick (headless, started by watch.sh)
The prompt names the state dir and lists the events. Read `state.md`,
rebuild the findings list, react to each event per the table, then reply
with one message from the list below or with no text at all. The reply
is the whole conversation with the user: its first line becomes the
notification, the full text goes to `log.md`. A reply that starts with
APPROVED or STOPPED also ends the watch.

| Event | Reaction |
|---|---|
| `NEW_COMMIT <sha>` | Verify, then decide. |
| `NEW_COMMENT` / `NEW_INLINE` by the author | Answer to an open item → update that item. Question to the user → ACTION message. |
| `NEW_COMMENT` / `NEW_INLINE` by someone else | Note it. The findings list does not change. |
| `NEW_REVIEW` | By the author: same as a comment. By someone else: note it. |
| `REVIEW_REQUESTED` | Author says done. Head moved since `verifiedSha` → verify all open items, then decide. Head unchanged and an ACTION is open → silent, the user already has the question. Head unchanged and no ACTION open → ACTION: "author says done, items X untouched". |
| `CHECKS pass` / `CHECKS fail` | If a decide waits on CI, decide now. Else note it. |
| `PR_STATE MERGED` / `CLOSED` | Send the STOPPED message. |

watch.sh handles the rest itself: three failed polls in a row and 48h
without an event both end the watch with a STOPPED notification.

## Verify
1. `git fetch origin pull/<pr>/head <base>`.
2. Select the author's own commits:
   - `lastSha` is an ancestor of head (`git merge-base --is-ancestor`) →
     `git log --first-parent --no-merges <lastSha>..<headSha>`. This skips
     merges of the base and the base commits they bring in.
   - Else (force-push or rebase) → the range is `<merge-base>..<headSha>`
     against the base, and every open item is in scope.
   - No author commits (only a base merge) → set `lastSha`, stay silent.
3. Dispatch ONE verifier agent with `verifier-prompt.md`, filled in. Its
   worktree goes under the state dir: `<state dir>/verify-worktree`.
   Verdicts hold for the code at `headSha`. The per-commit diffs only show
   where to look: a later commit can undo an earlier fix.
4. Read the verdict critically. Spot-check one FIXED claim in the diff
   yourself. An agent handed a hypothesis tends to confirm it.

## Decide (three outcomes)
- **Approve**: every item FIXED, CI `pass` (`gh pr checks`), no new scope,
  no sensitive change → `gh pr review --approve` with a body that names the
  verified items and the verifier model+effort. Resolve only threads the
  user started. Send the APPROVED message. The watch ends.
- **Ask the user**: any NOT FIXED, UNSURE, new scope, sensitive change, a
  question from the author, or CI `fail` when all else is ready → do NOT
  approve. Send the ACTION message with ONE question. The watch goes on;
  the user answers by acting on the PR or in a normal session.
- **Silent wait**: CI `pending`; or the commit is clean but open items are
  untouched and the author has not replied to them → record, reply with
  no text, the watch goes on.

## Messages (the only text a tick may produce)
Line 1 is the headline: an icon, a status word, the PR, and the point.
Under 90 characters, because it is the notification title. No prose before
it. Then a blank line, then the body. Four messages exist:

1. Setup only, in the session:
   `👀 WATCHING PR #N: <k> open items · <model>/<effort> · every <minutes> min`
   Body: the numbered findings list, then the state dir.
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
   `⏹ STOPPED PR #N: <merged | closed | your word>`

Never send: progress, reminders, or "nothing new". One ACTION per open
question; send it again only with new information, and then say what is
new in step 1.

## State file
Keep `<state dir>/state.md`: model, effort, `lastSha`, `verifiedSha`
(head at the last verify), the findings with their status, the open
ACTION if any. Each event tick is a fresh process, so this file is the
only memory. Write it after every tick that changed something. Do not put
this in project memory.

## Sensitive change
A change that is hard to reverse after merge, or that can lose data, money,
or access. Default list: persisted state or schema migrations; payment,
billing, or balance logic; auth, permissions, or secrets; public API or wire
contracts; durable jobs that must stay compatible with in-flight runs.
If the project's CLAUDE.md names sensitive areas, that list wins.

## Rules
- The watch ends only on approval, PR close, the user's word, three failed
  polls, or 48h after the last PR event.
- Do not invoke a code-review skill for this. Diff + findings only.
- Do not commit, push, or check out anything in the user's worktree.
- Match the repo's language and tone rules for GitHub text.

## Red flags — STOP, message the user
- Sending the WATCHING message without an armed relay. The user then only
  gets a notification, which macOS may drop silently.
- Any text in a silent-wait tick ("PR unchanged, still watching"). Reply
  with nothing.
- "Probably fine, the author says it is fixed"
- "Only a small extra change, approving anyway"
- The verifier says UNSURE and you want to upgrade it to FIXED
