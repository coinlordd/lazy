#!/usr/bin/env bash
# Watches one PR from launchd, outside any Claude session.
#   watch.sh install <pr> <minutes>   from the PR's checkout; prints the state dir
#   watch.sh poll <state-dir>         one poll; launchd runs this every <minutes>
#   watch.sh stop <state-dir>         remove the launchd job
# A quiet poll does nothing. On events it runs one headless Claude turn that
# follows SKILL.md "Event tick", shows the reply's headline as a macOS
# notification, and appends the reply to <state-dir>/log.md.
set -o pipefail
here=$(cd "$(dirname "$0")" && pwd)
cmd=$1

stop() { launchctl bootout "gui/$(id -u)/$label" 2>/dev/null; rm -f "$HOME/Library/LaunchAgents/$label.plist"; }
notify() {  # $1 headline, $2 body
  local t=${1//\"/\\\"} b=${2//\"/\\\"}
  osascript -e "display notification \"$b\" with title \"$t\"" >/dev/null 2>&1
}

if [ "$cmd" = install ]; then
  pr=$2 minutes=${3:-20}
  slug=$(gh repo view --json nameWithOwner --jq .nameWithOwner | tr / -) || exit 1
  dir=$HOME/.claude/reviews/$slug/await-pr$pr
  label=lazy.await.$slug-pr$pr
  mkdir -p "$dir" "$HOME/Library/LaunchAgents"
  printf 'pr=%s\ncheckout=%q\nlabel=%s\n' "$pr" "$PWD" "$label" > "$dir/config"
  bash "$here/monitor.sh" "$pr" "$dir/monitor" >/dev/null || exit 1  # baseline
  touch "$dir/event"
  stop  # a previous watch of this PR
  # shortcut: PATH goes in unescaped, breaks on '&' or '<' in PATH; XML-escape when that happens
  cat > "$HOME/Library/LaunchAgents/$label.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key><array>
    <string>/bin/bash</string><string>$here/watch.sh</string><string>poll</string><string>$dir</string>
  </array>
  <key>StartInterval</key><integer>$((minutes * 60))</integer>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>$PATH</string></dict>
  <key>StandardOutPath</key><string>$dir/launchd.log</string>
  <key>StandardErrorPath</key><string>$dir/launchd.log</string>
</dict></plist>
EOF
  launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$label.plist" || exit 1
  echo "$dir"
  exit 0
fi

dir=$2
. "$dir/config" || exit 1
[ "$cmd" = stop ] && { stop; exit 0; }
[ "$cmd" = poll ] || { echo "usage: watch.sh install|poll|stop" >&2; exit 2; }
cd "$checkout" || exit 1

events=$(bash "$here/monitor.sh" "$pr" "$dir/monitor")
if [ $? -ne 0 ]; then
  n=$(( $(cat "$dir/fails" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$dir/fails"
  [ "$n" -ge 3 ] && { notify "⏹ STOPPED PR #$pr: poll failed" "3 polls in a row failed. See $dir/launchd.log"; stop; }
  exit 0
fi
rm -f "$dir/fails"
if [ -z "$events" ]; then
  [ -n "$(find "$dir/event" -mmin +2880 2>/dev/null)" ] && { notify "⏹ STOPPED PR #$pr: 48h quiet" ""; stop; }
  exit 0
fi
touch "$dir/event"

reply=$(claude -p --dangerously-skip-permissions "Read $here/SKILL.md and do one \"Event tick\" for PR #$pr.
State dir: $dir
Events:
$events")
printf '\n## %s\n%s\n' "$(date '+%Y-%m-%d %H:%M')" "${reply:-(silent)}" >> "$dir/log.md"

headline=$(printf '%s\n' "$reply" | grep -m1 -E '^(🔴|✅|⏹) ')
[ -n "$headline" ] && notify "$headline" "$(printf '%s\n' "$reply" | sed '1,2d' | head -c 200)"
case $headline in "✅ "*|"⏹ "*) stop ;; esac
exit 0
