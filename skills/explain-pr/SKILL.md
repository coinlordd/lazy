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

## Style (terminal and file)
Write ASD-STE100 Simplified Technical English. The reader is tired and has ADHD.
- Conclusion first. Details after.
- Sentences of 20 words or less. Active voice. One word per idea.
- One idea per block. Short paragraphs. Short responses.
- Simplify the language, never the technical content. Keep exact terms,
  `file:line`, and data shapes.
- Always English.

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
## Contents                 one line per chapter
## Introduction             what, 2–3 sentences
## Background               why; what is missing today
## Assumptions              one per line, tagged `stated` or `inferred`
## Chapter N: <flow> (<tag>)
### <subheading>            one-liners; a short paragraph where needed
**Takeaway:** one line
```

`stated` = the PR text says it. `inferred` = you guessed it from the code.

## Phase 1: what and why
Write Contents, Introduction, Background, Assumptions, and the chapter titles.
Each chapter title gets one line: what the flow does and why it changes.
Never the how. No traces in Phase 1.

## Phase 2: the how
Fill one chapter with its trace (per the tag table). End with the takeaway.

## Delivery
Standalone: Phase 1, then Phase 2 for each chapter, in order.
- Terminal, turn 1: the Contents only. The rest of Phase 1 goes to the file.
- Terminal, next turns: one chapter per turn. Wait for the user between
  chapters.
- File: write the full book. Update it after each chapter.

One chapter only → the book collapses. Drop Contents and Introduction from
the file. Terminal, turn 1: the trace directly.

Inside `lazy:design-review`: run only the phase it asks for, per flow.
A one-chapter book does not collapse there. Phase 1 shows the problem
statement for that flow in the terminal, instead of the Contents. The trace
waits until design-review asks for Phase 2.

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
