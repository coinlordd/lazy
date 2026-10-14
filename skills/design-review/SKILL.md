---
name: design-review
description: >
  Use when the user wants an architecture or design judgement of a PR:
  "design review", "review the design of this PR", "architecture review",
  "does this fit the codebase". Not a bug hunt; /code-review does that.
argument-hint: "[pr-number|pr-url] [model]"
---

# Design Review

Judge the design of one PR against the criteria below. Not a bug hunt.
Nothing goes to GitHub before the user approves each comment and the
review type. Uses `lazy:explain-pr`: Phase 1 once, Phase 2 per flow.

## Input
`/lazy:design-review <pr> <model>`, both optional.
- pr: a PR number or URL. Empty → the PR of the current branch.
- model: opus (default), sonnet, haiku, fable. Model for the trace subagents
  only (step 3b). The grill, the compare, and the drafts run on the session
  model. State the resolved model once.

**Guard, before anything else:** the session model is in your system prompt.
Not Fable → ask: "This session runs on <model>, not Fable. Continue, or stop
so you can run `/model fable` first?" Wait for the answer.

Never touch the user's worktree.

## Style
The reader (you, and the PR author) is tired, has ADHD, and has not read the
code yet. Write ASD-STE100 Simplified Technical English, in English.
- Conclusion first. Sentences of 20 words or less. Active voice.
- One idea per block. Short.
- Define every repo term on first use, in plain words, in the same sentence.
  This applies to grill questions too.
- One concrete example with real values beats an abstract description.
- Simplify the words, never the facts. Keep `file:line` and data shapes.

## Criteria, in priority order
Critical data path = any flow that moves valuable user data or money,
internally or through an external API.
1. **Data correctness.** Writes are idempotent; the key is persisted BEFORE
   the external call. A crash causes no loss and no duplicates. No critical
   state only in memory. Each state transition is one DB transaction.
2. **Recovery.** Resume or safe replay after a crash at any line. Retries
   have backoff, a limit, and run only for safe-to-retry errors. Side effects
   go through an outbox or similar. Failures land somewhere visible.
3. **Bottlenecks.** No lock or transaction open during an external call. No
   head-of-line blocking. External calls have timeouts. Pools and queues have
   limits. No slow sync work in the request path. Every cross-service wait
   has a deadline and a defined outcome (retry, cancel, alert). Stuck state
   is visible. Intentional blocking is stated in the PR.
4. **Fit.** Reuse existing clients, caches, retry helpers, DB patterns, and
   queues. Point to the existing one with `file:line`.
5. **Ownership.** Each piece of critical data has one owner. Only the owner
   writes it. Others ask the owner or react to its events.
6. **API economy.** No call in a loop where a batch endpoint exists. Every
   cache has a TTL or an invalidation rule. Identical concurrent requests are
   deduplicated. Webhooks over polling. Rate limits respected.
7. **Performance.** Low priority.

Out of scope: bugs, compile speed, regression tests, code style.

## Flow
1. Run explain-pr Phase 1. Note each flow, its tag, and every `inferred`
   assumption. If it asks the user for the problem, wait.
2. Dispatch one Explore subagent (`model: sonnet`, very thorough) in the
   background: existing HTTP clients, cache layers, retry helpers, DB access
   patterns, queue/outbox usage, idempotency helpers, each with `file:line`.
   Only step 4 waits for it.
3. Per flow, in Contents order. `same behavior` flows skip this step; they
   get only steps 4 and the ownership check on the diff.
   a. **Blind grill.** Ask how the USER would design this flow, before they
      see the implementation. Up to 6 numbered questions, in criterion order.
      Every `inferred` assumption that touches a criterion becomes a question.
      Each question has a recommended answer:
      ```
      ❓ **Q1** - **Idempotency key**: Where do you persist it, and when?
      ➡️ Before the external call, in the same transaction as the order row.
      ```
      "stop" → no more questions for any flow. Continue with steps 4–7.
   b. Dispatch one `general-purpose` subagent, `model: <model>`. It loads
      `lazy:explain-pr` and returns Phase 2 for this flow only. Give it the
      PR, the flow, and its tag. Show the trace. Append the chapter to the
      book yourself.
   c. Compare the user's answers with the PR, per criterion:
      PR is better → "Design choices confirmed": `Good: X, because Y`.
      User is better → finding. Equal → drop.
4. **Fit check** with the Explore results. A new pattern next to an existing
   one is a finding, with the existing one's `file:line`. Exception: the PR
   states why the existing one does not fit → judge that reason.
5. Draft all comments. The user approves, edits, or drops each one.
6. Suggest the review type: a finding on data correctness or recovery →
   "request changes"; else "comment". The user chooses. Post one review:
   `gh api repos/{owner}/{repo}/pulls/<pr>/reviews --input review.json` with
   `event`, `body`, and `comments[]` (`path`, `line`, `side`, `body`).
7. Append the findings and the confirmed choices to the book file.

## Comment format
Inline comment, three lines:
```
**Decision:** what the PR does here
**Criterion:** name - why this fails it
**Existing pattern:** `src/lib/retry.ts:12` - how to use it here
```
Review body:
```
This is not a bug hunt. Comments cover design choices only.

## Findings
- criterion: one line (`file:line`)

## Design choices confirmed
- Good: X, because Y.
```

## Rules
- Never post without explicit approval of each comment and the review type.
- "PR is better" is a lesson. It goes in the review body and the book.
- Do not invoke `code-review` or `await-verify-changes` from here.
- Never show a trace before the grill answers are in.
- Every finding names a criterion and a `file:line`.
- You start listing bugs → stop, point to `/code-review`.
