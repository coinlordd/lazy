#!/usr/bin/env bash
# Emits one line per new PR event. Polls GitHub every 5 minutes.
# Usage: bash monitor.sh <pr-number> <state-dir>
# Run it from a checkout of the PR's repo. <state-dir> keeps what was already
# seen, so a re-arm continues where the last run stopped. The first run only
# records a baseline and emits nothing for it.
set -o pipefail
pr=$1 dir=$2 interval=${AWAIT_VERIFY_INTERVAL:-300}
api="repos/{owner}/{repo}"
mkdir -p "$dir" && touch "$dir/seen"
me=$(gh api user --jq .login) || exit 1

# One "key<TAB>event" line per issue comment, inline comment, and review that
# is not from me or a bot. Thread replies come in as inline comments, so a
# review with state COMMENTED and an empty body carries no information.
items() {
  local t='def t: (.body // "") | gsub("\\s+"; " ") | .[0:160];'
  local who='select(.user.login != $me and .user.type != "Bot")'
  gh api --paginate "$api/issues/$pr/comments" | jq -r --arg me "$me" \
    "$t .[] | $who"' | "c\(.id)\tNEW_COMMENT \(.user.login): \(t)"' &&
  gh api --paginate "$api/pulls/$pr/comments" | jq -r --arg me "$me" \
    "$t .[] | $who"' | "i\(.id)\tNEW_INLINE \(.user.login) \(.path):\(.line // .original_line): \(t)"' &&
  gh api --paginate "$api/pulls/$pr/reviews" | jq -r --arg me "$me" \
    "$t .[] | $who"' | select(.state != "COMMENTED" or t != "") | "r\(.id)\tNEW_REVIEW \(.user.login) \(.state): \(t)"'
}

# Aggregate CI state at head: pass, fail, pending, or none.
checks() {
  gh pr checks "$pr" --json bucket 2>/dev/null | jq -r 'map(.bucket)
    | if any(. == "fail" or . == "cancel") then "fail"
      elif any(. == "pending") then "pending"
      elif length > 0 then "pass" else "none" end'
}

first=1; [ -s "$dir/sha" ] && first=0
emit() { [ "$first" = 1 ] || echo "$1"; }
changed() { [ "$(cat "$dir/$1" 2>/dev/null)" != "$2" ] && echo "$2" > "$dir/$1"; }

while true; do
  if j=$(gh api "$api/pulls/$pr") && list=$(items); then
    st=$(jq -r 'if .state == "open" then "OPEN" elif .merged then "MERGED" else "CLOSED" end' <<<"$j")
    [ "$st" != OPEN ] && { echo "PR_STATE $st"; exit 0; }

    sha=$(jq -r .head.sha <<<"$j")
    changed sha "$sha" && emit "NEW_COMMIT $sha"

    while IFS=$'\t' read -r key ev; do
      [ -n "$key" ] && ! grep -qxF "$key" "$dir/seen" || continue
      echo "$key" >> "$dir/seen"; emit "$ev"
    done <<<"$list"

    rr=$(jq -r --arg me "$me" 'any(.requested_reviewers[]; .login == $me)' <<<"$j")
    changed rr "$rr" && [ "$rr" = true ] && emit "REVIEW_REQUESTED"

    ci=$(checks); ci=${ci:-none}
    changed ci "$ci" && case $ci in pass|fail) emit "CHECKS $ci";; esac

    first=0
  fi
  sleep "$interval"
done
