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
| `/lazy:await-verify-changes [model] [effort] [minutes]` | You reviewed a PR and want to wait for the author's fixes. See below. |
| `/lazy:explain-pr [pr]` | You want to understand a PR, not judge it. |
| `/lazy:design-review [pr] [model]` | You want an architecture judgement of a PR. Not a bug hunt. |
| `/lazy:skeleton-first` | A spec is approved and you want the wiring reviewable before any logic. |
| `/lazy:ponytail [lite\|full\|ultra]` | Any coding task: the smallest change that fully solves it. |

## await-verify-changes

The session only sets the watch up. It records your findings, then runs
`watch.sh install`, which loads a launchd job. That job runs `monitor.sh`
every `minutes` (default 20) with no model involved. A quiet poll produces
nothing: no turn, no text, no notification.

When the poll finds an event (a push, a comment, a review request, CI,
merge or close), it runs one headless `claude -p` turn. That turn verifies
the fixes with a verifier agent (`model`/`effort`, default opus/high),
then approves, asks you one question, or stays silent. Its first line is
a macOS notification. The full reply goes to `log.md`.

State lives in `~/.claude/reviews/<owner>-<repo>/await-pr<n>/`:
`state.md`, `log.md`, `launchd.log`, `config`.

The watch ends on approval, PR close, three failed polls, 48h without an
event, or `/lazy:await-verify-changes stop`. After a plugin update, start
running watches again: the launchd job points at the installed version.
