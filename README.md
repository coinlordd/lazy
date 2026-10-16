# lazy

Claude Code skills for a tired senior. Let the agent wait, verify, explain
and design-review PRs, scaffold before implementing, and keep things simple.

## Install

```
claude plugin marketplace add coinlordd/lazy
claude plugin install lazy@lazy
```

Update: `claude plugin update lazy@lazy`, then `/reload-plugins`.

## Skills

| Skill | Use it when |
|---|---|
| [`/lazy:await-verify-changes [model] [effort] [minutes]`](skills/await-verify-changes/README.md) | You reviewed a PR and want to wait for the author's fixes. |
| [`/lazy:explain-pr [pr]`](skills/explain-pr/README.md) | You want to understand a PR, not judge it. |
| [`/lazy:design-review [pr] [model]`](skills/design-review/README.md) | You want an architecture judgement of a PR. Not a bug hunt. |
| [`/lazy:skeleton-first`](skills/skeleton-first/README.md) | A spec is approved and you want the wiring reviewable before any logic. |
| [`/lazy:ponytail [lite\|full\|ultra]`](skills/ponytail/README.md) | Any coding task: the smallest change that fully solves it. |
