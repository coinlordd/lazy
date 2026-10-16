# await-verify-changes

Wait for the author's fixes on a PR you already reviewed. Verify them,
approve, or ask you one question.

```
/lazy:await-verify-changes [model] [effort] [minutes]
/lazy:await-verify-changes stop
```

Defaults: opus, high, 20. Run it from a checkout of the PR's repo.

## How it works
1. The session records your findings, runs `watch.sh install`, and shows
   the WATCHING message. Then it is done. Close it if you like.
2. A launchd job runs `monitor.sh` every `minutes`. No model. A quiet poll
   produces nothing.
3. On an event (push, comment, review request, CI, merge, close) it runs one
   headless `claude -p` turn. That turn verifies with a verifier agent, then
   approves, asks you one question, or stays silent.
4. The reply's first line is a macOS notification. The full reply goes to
   `log.md`.

## Files
- `watch.sh` — `install`, `poll`, `stop`.
- `monitor.sh` — one GitHub poll, prints one line per new event.
- `verifier-prompt.md` — the prompt for the verifier agent.
- State: `~/.claude/reviews/<owner>-<repo>/await-pr<n>/`.

## It stops on
Approval, PR close, three failed polls, 48h without an event, or `stop`.
After a plugin update, start running watches again.
