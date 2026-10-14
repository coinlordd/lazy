---
name: design-review
description: >
  Use when the user wants an architecture or design judgement of a PR:
  "design review", "review the design of this PR", "is this PR designed
  well", "architecture review", "does this fit the codebase". Not a bug hunt;
  /code-review does that.
argument-hint: "[pr-number|pr-url] [model]"
---
# Design Review

Judge the design of one PR against the criteria below. Not a bug hunt:
`/code-review` does that. Nothing goes to GitHub before the user approves
each comment and the review type.

**REQUIRED SUB-SKILL:** `lazy:explain-pr`, in two phases: Phase 1 once,
Phase 2 per flow.

## Input

`/lazy:design-review <pr> <model>`, both optional.
- pr: a PR number or URL. Empty → the PR of the current branch
  (`gh pr view --json number`).
- model: opus (default), sonnet, haiku, fable. Empty or unknown → opus.
  This is the model for the trace subagents (step 3b). The pattern search
  (step 2) always uses sonnet. The grill, the compare, and the drafts run in
  this session, on the session model.
State the resolved model once at the start, then never again.
Never check out or change the user's worktree.

## Style (terminal, review, file)

Write ASD-STE100 Simplified Technical English. The reader (reviewer and PR
author) is tired and has ADHD.

- Conclusion first. Details after.
- Sentences of 20 words or less. Active voice. One word per idea.
- One idea per block. Short paragraphs. Short responses.
- Simplify the language, never the technical content. Keep exact terms,
`file:line`, and data shapes.
- Always English.

## Criteria, in priority order

Critical data path = any flow that moves valuable user data or money,
internally or through an external API.

1. **Data correctness.** Writes are idempotent; the key is persisted BEFORE
 the external call. A crash causes no loss and no duplicates. No critical
 state only in memory. Each state transition is one DB transaction.
2. **Recovery.** Resume or safe replay after a crash at any line. Retries
 have backoff, a limit, and run only for safe-to-retry errors. Side effects
 go through an outbox or similar, not "write DB, call API, hope". Failures
 land somewhere visible (DLQ, status column).
3. **Bottlenecks.** No lock or transaction open during an external call. No
 head-of-line blocking (serial queue, single worker). External calls have
 timeouts. Pools and queues have limits. No slow sync work in the request
 path. Every cross-service wait has a deadline and a defined outcome
 (retry, cancel, alert). Stuck state is visible. Intentional blocking is
 stated in the PR.
4. **Fit.** Reuse existing clients, caches, retry helpers, DB patterns, and
 queues. Point to the existing one with `file:line`.
5. **Ownership.** Each piece of critical data has one owner. Only the owner
 writes it. Others ask the owner or react to its events.
6. **API economy.** No call in a loop where a batch endpoint exists. Every
 cache has a TTL or an invalidation rule. Identical concurrent requests are
 deduplicated. Webhooks over polling where available. Rate limits respected.

Out of scope: bugs, compile speed, regression tests, code style.

## Flow

1. Run explain-pr Phase 1. Note each flow, its tag, and every `inferred`
 assumption. If explain-pr asks the user for the problem, wait for the
 answer before step 2.
2. Dispatch one Explore subagent (`model: sonnet`, very thorough) in the
   background. Ask for
 the existing HTTP clients, cache layers, retry helpers, DB access patterns,
 queue/outbox usage, and idempotency helpers, each with `file:line`.
 Do not wait for it. Only step 4 waits for it.
3. Per flow, in book order. Flows tagged `same behavior` skip this step.
 They get only the fit check (step 4) and the ownership check: apply
 criterion 5 to the diff, with no questions to the user.
   a. **Blind grill round.** Before the user sees the implementation, ask how
    THEY would design this flow. Up to 6 numbered questions, ordered by
    criterion priority. Every `inferred` assumption that touches a criterion
    becomes a question. Each question has a recommended answer:
      ```
       ❓ **Q1** - **Idempotency key**: Where do you persist it, and when?
       ➡️ Before the external call, in the same transaction as the order row.
      ```
   
       The user says "stop" → no more grill questions, for this flow or
       later flows. Run steps 4–7 with the answers that exist.
   b. Dispatch one `general-purpose` subagent with `model: <model>`. Tell it
      to load `lazy:explain-pr` and return Phase 2 for this flow only: the
      chapter text with the trace. Give it the PR, the flow, its tag, and
      the book path. Show the trace. Append the chapter to the book yourself.
   c. Compare the user's answers with the PR, criterion by criterion:
    | Result | Action |
    |---|---|
    | PR is better | Record under "Design choices confirmed": `Good: X, because Y`. |
    | User's answer is better | Finding. |
    | Equal | Drop. |
4. **Fit check** with the Explore results. A new pattern next to an existing
 one is a finding; point to the existing one with `file:line`. Exception:
 the PR states why the existing one does not fit → judge that reason.
 Do not flag automatically.
5. Draft all comments. Show them to the user. The user approves, edits, or
 drops each one.
6. Suggest the review type: any finding on data correctness or recovery →
 "request changes"; else "comment". The user chooses. Post one review with
 body and inline comments:
 `gh api repos/{owner}/{repo}/pulls/<pr>/reviews --input review.json`
 where the JSON has `event` (`COMMENT` or `REQUEST_CHANGES`), `body`, and
 `comments[]` (each with `path`, `line`, `side`, `body`).
7. Append the findings and the confirmed choices to the book file
 (`~/.claude/reviews/<repo>/pr-<number>.md`).

## Comment format

Inline comment, three lines:

```
**Decision:** [[ORCA_RICH_MD:b82d05ad6750856c95da9d6506a00e17:inline-html:%3Cwhat%20the%20PR%20does%20here%3E]]
**Criterion:** [[ORCA_RICH_MD:b82d05ad6750856c95da9d6506a00e17:inline-html:%3Cname%3E]] - [[ORCA_RICH_MD:b82d05ad6750856c95da9d6506a00e17:inline-html:%3Cwhy%20this%20fails%20it%3E]]
**Existing pattern:** `src/lib/retry.ts:12` - [[ORCA_RICH_MD:b82d05ad6750856c95da9d6506a00e17:inline-html:%3Chow%20to%20use%20it%20here%3E]]
```

Review body:

```
This is not a bug hunt. Comments cover design choices only.

## Findings
- <criterion>: <one line> (`file:line`)

## Design choices confirmed
- Good: <X>, because <Y>.
```

## Rules

- Never post without explicit user approval of each comment and the review type.
- "PR is better" results are lessons for the user. Document them in the
review body and the book. Never keep them private.
- Do not invoke `code-review` or `await-verify-changes` from here. The user
calls those.

## Red flags - STOP

- You show the trace before the grill answers are in.
- A finding without a criterion or without `file:line`.
- "It is only a comment review, no need to ask" → ask.
- You drop a confirmed choice because it feels like lecturing.
- You start listing bugs. Stop. Point the user to `/code-review`.

