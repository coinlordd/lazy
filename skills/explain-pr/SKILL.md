---
name: explain-pr
description: >
  Use when the user wants to understand a PR, not judge it: "explain this PR",
  "walk me through this PR", "what does this PR do", "trace the data flow",
  "understand this change". Also called by lazy:design-review in two phases.
argument-hint: "[pr-number|pr-url]"
---

# Explain PR

Explain one PR step by step. Understanding only. No judgement, no advice,
nothing posted to GitHub.

## Input
`$ARGUMENTS` is a PR number or URL. Empty → the PR of the current branch.
Read `gh pr view <pr> --json title,body,commits,url`, `gh pr diff <pr>`, and
the linked issue. For code, `git fetch origin pull/<pr>/head` and read with
`git show <ref>:<path>`. Never touch the user's worktree.

## Style
The reader is a senior engineer, tired, with ADHD, who has not seen this repo.
Write ASD-STE100 Simplified Technical English, in English.
- Conclusion first. Sentences of 20 words or less. Active voice.
- One idea per block. Three sentences per paragraph at most.
- Define every repo term on first use, in plain words, in the same sentence:
  `term (what it means)`. Never use a term before you define it.
- One concrete example with real values beats an abstract description.
- Any step-by-step walk through events or a lifecycle is a numbered list.
  One event per item. Never prose, never a code block.
- Simplify the words, never the facts. Keep `file:line` and data shapes.
- Before you send: can the reader follow each sentence without opening the
  repo? If not, rewrite it.

## Step 1: The problem
Find the problem the PR solves. If the PR does not say it, infer it from the
diff, the issue, and the commits. State your confidence. Low → ask the user
for the problem in one line before you continue.

## Step 2: Flows and tags
A flow is one data path through the system. Split the PR into flows.

| Tag | Meaning | Trace |
|---|---|---|
| `fixed` | It was broken. Now it works. | Before: to ❌. After: same data point, to ✅. |
| `new` | It did not exist. | After: to ✅. |
| `changed` | It works differently now. | Before: to the old mutation. After: same data point, to ✅. |
| `same behavior` | Refactor or move. | None. One line: behavior unchanged, and why you are sure. |

## The trace
Follow ONE data point (one record, one payment, one message) from where it
enters the system, hop by hop, across services. No step limit. Each step:
service · function `file:line` · the data at that point. Stop at the
mutation that is the bug (❌) or the key new mutation (✅).

1. api · `createOrder()` `api/orders.ts:42` · `{id: 17, total: 1200, currency: "EUR"}`
2. queue · `publish()` `lib/queue.ts:10` · same object, as JSON
3. worker · `charge()` `worker/charge.ts:88` · ❌ sends `total` as euros; the API expects cents

## Phase 1: what and why
"The problem", in four short blocks:
1. The bug or the change, in one sentence.
2. What happens today: one example with real values, as a numbered list of
   events.
3. Why that is wrong: what the user or the business loses.
4. What the PR changes: one line per flow, plain words. Never the how.

Then the Contents (one line per flow, with its tag). Then the `inferred`
assumptions that matter, five at most. `inferred` = you guessed it from the
code. `stated` = the PR says it; those go to the file only. No trace here.

## Phase 2: the how
One chapter per flow: its trace, then a one-line takeaway.

## Delivery
Everything goes in the chat. The file is a copy, never the primary output.
- Turn 1: Phase 1.
- Next turns: one chapter per turn. Wait for the user between chapters.
- One flow only: skip the Contents; show the problem, then the trace.

File: `~/.claude/reviews/<repo>/pr-<number>.md`, `<repo>` =
`gh repo view --json nameWithOwner -q .nameWithOwner | tr / -`. Never inside
the reviewed repo. Sections: The problem, Contents, Assumptions (all, tagged),
one chapter per flow. No author, SHAs, or branch names. Update it after each
chapter.

Inside `lazy:design-review`: run only the phase it asks for. Phase 1 shows
blocks 1–3 only (block 4 would spoil the grill). The trace waits for Phase 2.

## Common mistakes
| Mistake | Fix |
|---|---|
| Trace describes code in general | Pick one data point and show its value at each step |
| Trace stops at a service boundary | Follow the data into the next service |
| One trace for a `changed` flow | Before and after, same data point |
| Phase 1 explains the fix | Move the how to Phase 2 |
| A repo term with no definition | Define it in the same sentence, or use a plain word |
| The chat got a summary, the file got the content | The content goes in the chat |
