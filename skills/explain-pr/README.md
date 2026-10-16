# explain-pr

Understand a PR. No judgement, no advice, nothing posted to GitHub.

```
/lazy:explain-pr [pr-number|pr-url]
```

Empty argument → the PR of the current branch.

## What you get
- **Phase 1, first turn:** the problem in four blocks. The bug, one example
  with real values, why it hurts, what the PR changes. Then the list of
  flows, each tagged `fixed`, `new`, `changed` or `same behavior`.
- **Phase 2, one turn per flow:** a trace. One data point, followed through
  each domain, with the values that matter. Say "next" for the next flow.

Everything lands in the chat. A copy goes to
`~/.claude/reviews/<owner>-<repo>/pr-<n>.md`.

Also used by `design-review`, one phase at a time.
