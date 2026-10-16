# design-review

Judge the design of a PR. Not a bug hunt; `/code-review` does that.

```
/lazy:design-review [pr-number|pr-url] [model]
```

`model` is for the trace subagents only. Default opus. The skill asks you
to switch to Fable first when the session runs on another model.

## Criteria, in order
Data correctness, recovery, bottlenecks, fit with existing patterns,
ownership, API economy, performance.

## How it works
1. `explain-pr` Phase 1: the problem and the flows.
2. Per flow, a blind grill: up to six questions on how you would design it,
   each with a recommended answer. Then the trace, then a compare. The PR
   wins → a confirmed choice. You win → a finding.
3. Fit check against existing clients, caches, retries and DB patterns.
4. Draft comments. You approve, edit or drop each one.
5. One review on GitHub, only after your approval of every comment and of
   the review type.

Findings and confirmed choices go to the same file as `explain-pr`.
