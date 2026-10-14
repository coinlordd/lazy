Repo: <owner/repo>. PR #<n> "<title>" (author <login>, branch `<branch>`, base <base>).
Head: <headSha>. CI at head: <pass/fail/pending/none>.
User worktree (read only): <user worktree path>.
Your worktree: <scratchpad>/pr<n>-verify.

Commits to judge (author commits only, oldest first):
- `git diff <parent>..<commit>`: <sha> "<message>"
- ...

Findings, verbatim from the user:
1. <finding>
2. ...
N. REGRESSION-FREE: list every behavior change beyond the stated intent.
N+1. NEW SCOPE: anything unrelated to the review feedback?

Checks: the type check for <packages touched>, and exactly these test
files: <list>.
