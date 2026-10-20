#!/usr/bin/env bash
# Relays an event tick's reply into the session that set up the watch.
#   relay.sh <state-dir> [from-line]
# Waits until <state-dir>/log.md has a headline line (🔴 ✅ ⏹) past line
# <from-line>, prints everything after <from-line>, and exits. A session runs
# it with Bash run_in_background, so the chat gets one message per event.
# It never prints on quiet waits; a timeout just means re-arm.
dir=$1 from=$(( ${2:-0} ))
log=$dir/log.md
while true; do
  n=$(( $( [ -f "$log" ] && wc -l < "$log" || echo 0 ) ))
  if [ "$n" -gt "$from" ] && tail -n +"$((from + 1))" "$log" | grep -q -E '^(🔴|✅|⏹) '; then
    tail -n +"$((from + 1))" "$log"
    exit 0
  fi
  launchctl print "gui/$(id -u)/$(sed -n 's/^label=//p' "$dir/config")" >/dev/null 2>&1 || { echo "⏹ WATCH GONE: launchd job for $dir is no longer loaded"; exit 0; }
  sleep 30
done
