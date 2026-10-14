---
name: explain-pr
description: >
  Use when the user wants to understand a PR, not judge it: "explain this PR",
  "walk me through this PR", "what does this PR do", "trace the data flow",
  "understand this change". Also the sub-skill lazy:design-review calls in
  two phases.
argument-hint: "[pr-number|pr-url]"
---

# Explain PR

Explain one PR and its architecture, step by step. Understanding only.
Do not judge. Do not post anything.

## Input
`$ARGUMENTS` is a PR number or URL. Empty → the PR of the current branch
(`gh pr view --json number`).
Read with `gh pr view <pr> --json title,body,commits,url`, `gh pr diff <pr>`,
and the linked issue if any. For code, fetch the head and the base
(`git fetch origin pull/<pr>/head`) and read with `git show <ref>:<path>`.
Never check out or change the user's worktree.

## Style (chat and file)
Write ASD-STE100 Simplified Technical English. The reader is a senior
engineer, tired, with ADHD, and has NOT seen this repo. Explain it like
Feynman: simple words, exact facts.
- Conclusion first. The first line names the bug or the change in one sentence.
- Sentences of 20 words or less. Active voice. One word per idea.
- One idea per block. Three sentences per paragraph at most.
- Define every repo term on first use, in plain words, in the same sentence.
  Example: "a synthetic fill (a fill the client invents to explain a position
  it cannot match)". No term is used before it is defined.
- Show one concrete example with real values (one symbol, one amount, one
  timestamp). Prefer the example over an abstract description.
- Simplify the language, never the technical content. Keep exact terms,
  `file:line`, and data shapes.
- Always English.
- Self-check before you send: can the reader follow every sentence without
  opening the repo? If not, rewrite that sentence.

## Step 1: The problem
Find the problem the PR solves. If the PR does not say it, infer it from the
diff, the linked issue, and the commits. State your confidence (high, medium,
low). Low → ask the user for the problem in one line before you continue.

## Step 2: Flows and tags
A flow is one data path through the system. Split the PR into flows.
Tag each flow:

| Tag | Meaning | Trace |
|---|---|---|
| `fixed` | It was broken. Now it works. | Before: trace to ❌. After: the same data point through the fix, to ✅. |
| `new` | It did not exist before. | After: trace to ✅. |
| `changed` | It worked. Now it works differently. | Before: trace to the old mutation. After: same data point, to ✅. |
| `same behavior` | Refactor or move. | No trace. Confirm in one line that behavior is unchanged. |

## The trace
Follow ONE concrete data point: one user record, one payment, one message.
Start where it enters the system. Go hop by hop, across services.
No step limit. Each step has three parts: service · function with
`file:line` · what the data looks like at that point.
Stop at the mutation that is the bug (mark ❌) or the key new mutation (mark ✅).

```
1. api · `createOrder()` `api/orders.ts:42` · `{id: 17, total: 1200, currency: "EUR"}`
2. queue · `publish()` `lib/queue.ts:10` · same object, JSON string
3. worker · `charge()` `worker/charge.ts:88` · ❌ sends `total` as euros; the API expects cents
```

## The book
Every PR becomes a book at `~/.claude/reviews/<repo>/pr-<number>.md`.
`<repo>` = `gh repo view --json nameWithOwner -q .nameWithOwner | tr / -`.
Never write it inside the reviewed repo. One flow = one chapter. Structure:

```
# PR <number>: <title>
## The problem              see Phase 1
## Contents                 one line per chapter
## Assumptions              one per line, tagged `stated` or `inferred`
## Chapter N: <flow> (<tag>)
### <subheading>            one-liners; a short paragraph where needed
**Takeaway:** one line
```

`stated` = the PR text says it. `inferred` = you guessed it from the code.
No author, commit SHAs, or branch names. The reader has `gh` for that.

## Phase 1: what and why
Write "The problem" in four short blocks:
1. **The bug or the change, in one sentence.**
2. **What happens today**, as one concrete example with real values.
3. **Why that is wrong**: what the user or the business loses.
4. **What the PR changes**: one line per flow, in plain words. Never the how.

Then the Contents: one line per chapter, with its tag.
Then the Assumptions. Never a trace in Phase 1.

## Phase 2: the how
Fill one chapter with its trace (per the tag table). End with the takeaway.

## Delivery
The explanation lives in the chat. The file is a copy for later, never
the primary output. Never say "see the file" for something you did not show.

Standalone: Phase 1, then Phase 2 for each chapter, in order.
- Chat, turn 1: "The problem", the Contents, and the `inferred` assumptions
  only (five at most, the ones that matter). `stated` assumptions go to the
  file only.
- Chat, next turns: one chapter per turn. Wait for the user between chapters.
- File: write the full book. Update it after each chapter.

One chapter only → the book collapses. Drop the Contents. Chat, turn 1:
"The problem", then the trace directly.

Inside `lazy:design-review`: run only the phase it asks for, per flow.
A one-chapter book does not collapse there. Phase 1 shows "The problem" for
that flow in the chat, without block 4. The trace waits until design-review
asks for Phase 2.

## Rules
- No judgement. No "should", no findings, no advice.
- Nothing goes to GitHub.
- Phase 1 never contains a trace.

## Common mistakes
| Mistake | Fix |
|---|---|
| Trace describes code in general | Pick one data point and show its value at each step |
| Trace stops at a service boundary | Follow the data into the next service |
| One trace for a `changed` flow | Before trace and after trace, same data point |
| A trace for a `same behavior` flow | One line: behavior unchanged, and why you are sure |
| Phase 1 explains the fix | Move the how to Phase 2 |
| Assumption without a tag | Tag it `stated` or `inferred` |
| A repo term with no definition ("fill horizon") | Define it in plain words in the same sentence, or use a plain word |
| Abstract description, no example | Add one example with real values |
| The content went to the file, the chat got a summary | Put the content in the chat; the file is the copy |
| More than five assumptions in the chat | Keep the `inferred` ones that matter; the rest go to the file |
