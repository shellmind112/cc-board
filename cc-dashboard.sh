#!/bin/bash
# cc-board: scan every live `claude` process (= how many CC sessions you really
# have open), enrich each with its state (running / waiting / done) + the task
# you gave it, read from /tmp/cc-status/. Untouched sessions show as "idle".
# Column alignment is handed off to cc-format.py (display-width aware).
# Pass --once to render a single frame (for testing).
DIR=/tmp/cc-status
FMT="$(dirname "$(readlink -f "$0")")/cc-format.py"   # cc-format.py next to this script

rows() {  # emit TSV: state \t project \t task \t updated
  local now pid tty id file s t ti pr fpid state ts title proj label prio age agestr
  now=$(date +%s)
  while read -r pid tty; do
    [ -z "$pid" ] && continue
    id=$(printf '%s' "$tty" | tr '/' '-')          # pts/8 -> pts-8
    file="$DIR/$id"
    state=idle; title="(not started)"; ts=""; proj=""
    if [ -f "$file" ]; then
      # split on tabs WITHOUT collapsing empty fields -- `IFS=$'\t' read` would
      # merge consecutive tabs (tab is IFS-whitespace) and shift the columns when
      # a field such as the task is empty, leaving fpid blank -> misread as idle.
      mapfile -t F < <(awk -F'\t' 'NR==1{print $1;print $2;print $3;print $4;print $5}' "$file")
      s=${F[0]}; t=${F[1]}; ti=${F[2]}; pr=${F[3]}; fpid=${F[4]}
      if [ -n "$fpid" ] && kill -0 "$fpid" 2>/dev/null; then   # trust it only if the writer is still alive
        state="$s"; ts="$t"; title="$ti"; proj="$pr"
      fi
    fi
    [ -z "$proj" ] && proj=$(basename "$(readlink /proc/$pid/cwd 2>/dev/null)" 2>/dev/null)
    [ -z "$proj" ] && proj="?"
    # prio drives row order in render(): surface what needs YOU first.
    # waiting (blocked on you) > done (go look) > running (nothing to do) > idle.
    case "$state" in
      waiting) label="🟡 waiting"; prio=1 ;;
      done)    label="✅ done";    prio=2 ;;
      running) label="🔴 running"; prio=3 ;;
      idle)    label="⚪ idle";    prio=4 ;;
      *)       label="◽ $state";  prio=5 ;;
    esac
    if [ -n "$ts" ]; then
      age=$(( now - ts ))
      if   [ "$age" -lt 60 ];   then agestr="${age}s ago"
      elif [ "$age" -lt 3600 ]; then agestr="$((age/60))m ago"
      else                           agestr="$((age/3600))h ago"; fi
    else agestr="—"; fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$prio" "$label" "$proj" "$title" "$agestr"
  done < <(ps -eo pid=,tty=,comm= 2>/dev/null | awk '$3=="claude" && $2 ~ /^pts/ && !seen[$2]++ {print $1, $2}')
}

render() {
  printf ' cc-board   refreshes every 2s · Ctrl+C to quit\n'
  rows | sort -t$'\t' -k1,1n -s | cut -f2- | python3 "$FMT"
}

if [ "$1" = "--once" ]; then render; exit 0; fi
while true; do clear; render; sleep 2; done
