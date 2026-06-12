#!/bin/bash
# cc-board: scan every live `claude` process (= how many CC sessions you really
# have open), enrich each with its state (running / waiting / done) + the task
# you gave it, read from /tmp/cc-status/. Untouched sessions show as "idle".
# Column alignment is handed off to cc-format.py (display-width aware).
# Optionally (CC_BOARD_DOCKER=1) also list claude sessions running inside Docker
# containers, read from /tmp/cc-status-docker/ (see README "Docker support").
# Pass --once to render a single frame (for testing).
DIR=/tmp/cc-status
DDIR=/tmp/cc-status-docker     # container sessions land here -- kept separate from host for isolation
FMT="$(dirname "$(readlink -f "$0")")/cc-format.py"   # cc-format.py next to this script

# Map a state (+ optional timestamp) to its display label, sort priority, and
# "x ago" string. Sets globals label/prio/agestr. Shared by host & container rows.
fields_for() {  # $1=state  $2=ts   (uses global $now)
  case "$1" in
    waiting) label="🟡 waiting"; prio=1 ;;
    done)    label="✅ done";    prio=2 ;;
    running) label="🔴 running"; prio=3 ;;
    idle)    label="⚪ idle";    prio=4 ;;
    *)       label="◽ $1";      prio=5 ;;
  esac
  if [ -n "$2" ]; then
    local age=$(( now - $2 ))
    if   [ "$age" -lt 60 ];   then agestr="${age}s ago"
    elif [ "$age" -lt 3600 ]; then agestr="$((age/60))m ago"
    else                           agestr="$((age/3600))h ago"; fi
  else agestr="—"; fi
}

rows() {  # emit TSV: prio \t state \t project \t task \t updated  (prio stripped after sorting)
  local now pid tty id file s t ti pr fpid state ts title proj label prio agestr cid cname
  now=$(date +%s)

  # --- host sessions: live `claude` processes attached to a pts ---
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
    fields_for "$state" "$ts"
    printf '%s\t%s\t%s\t%s\t%s\n' "$prio" "$label" "$proj" "$title" "$agestr"
  done < <(ps -eo pid=,tty=,comm= 2>/dev/null | awk '$3=="claude" && $2 ~ /^pts/ && !seen[$2]++ {print $1, $2}')

  # --- container sessions (opt-in: CC_BOARD_DOCKER=1; needs docker) ---
  # A container's claude is in its own PID namespace, so the host `ps` can't see
  # it. Ask docker which containers are running (= alive, since claude is the
  # container's main process) and read each one's note from $DDIR. The whole block
  # is gated, so users without docker -- or who don't opt in -- pay nothing.
  if [ -n "$CC_BOARD_DOCKER" ] && command -v docker >/dev/null 2>&1; then
    while read -r cid cname; do
      [ -z "$cid" ] && continue
      file="$DDIR/docker-$cid"
      [ -f "$file" ] || continue                   # only show containers that wrote a note
      mapfile -t F < <(awk -F'\t' 'NR==1{print $1;print $2;print $3;print $4}' "$file")
      state=${F[0]}; ts=${F[1]}; title=${F[2]}; proj=${F[3]}
      [ -z "$proj" ] && proj="$cname"
      fields_for "$state" "$ts"                    # liveness is implicit: it's in `docker ps`
      printf '%s\t%s\t%s\t%s\t%s\n' "$prio" "$label" "🐳 $proj" "$title" "$agestr"
    done < <(timeout 3 docker ps --format '{{.ID}} {{.Names}}' 2>/dev/null)
  fi
}

render() {
  printf ' cc-board   refreshes every 2s · Ctrl+C to quit\n'
  rows | sort -t$'\t' -k1,1n -s | cut -f2- | python3 "$FMT"
}

if [ "$1" = "--once" ]; then render; exit 0; fi
while true; do clear; render; sleep 2; done
