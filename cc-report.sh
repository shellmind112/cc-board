#!/bin/bash
# Called from Claude Code hooks: writes THIS session's state to /tmp/cc-status/<pts>
# for the dashboard to read.
# $1 = state: running / waiting / done
# Claude Code passes a JSON context on stdin (has cwd; UserPromptSubmit also has your prompt).
state="${1:-running}"
input=$(cat 2>/dev/null)

# Walk up the process tree to find this session's `claude` process, and use the
# terminal (pts) it's attached to as a unique key -- so each tab's CC writes its
# own file without clobbering the others.
pid=$$
while [ "$pid" -gt 1 ]; do
  [ "$(cat /proc/$pid/comm 2>/dev/null)" = "claude" ] && break
  pid=$(awk '/^PPid:/{print $2}' /proc/$pid/status 2>/dev/null)
  [ -z "$pid" ] && break
done
tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
{ [ -z "$tty" ] || [ "$tty" = "?" ]; } && tty="unknown"
id=$(printf '%s' "$tty" | tr '/' '-')   # pts/8 -> pts-8

mkdir -p /tmp/cc-status
file="/tmp/cc-status/$id"

# Pull cwd and prompt out of the JSON with python3 (already required by cc-format.py).
# Real JSON parsing correctly handles escaped quotes/newlines that a regex mangles
# (e.g. a prompt like:  add a "save" button).
eval "$(printf '%s' "$input" | python3 -c '
import sys, json, shlex
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
print("cwd="    + shlex.quote(d.get("cwd")    or ""))
print("prompt=" + shlex.quote(d.get("prompt") or ""))
')"
[ -z "$cwd" ] && cwd="$PWD"
# Label the tab by the claude process's REAL cwd (its launch dir), not the cwd the
# hook reports: an agent `cd`-ing into a subfolder (e.g. ./papers) shifts the hook's
# logical cwd but NOT the process cwd, which stays at launch. Fall back to hook cwd.
projdir=$(readlink "/proc/$pid/cwd" 2>/dev/null)
[ -z "$projdir" ] && projdir="$cwd"
proj=$(basename "$projdir")

# title (the "Task" column): update it when we got a prompt; otherwise keep the existing one.
if [ -n "$prompt" ]; then
  title="$prompt"
else
  title=$(awk -F'\t' 'NR==1{print $3}' "$file" 2>/dev/null)
fi
title=$(printf '%s' "$title" | tr '\t\n\r' '   ')   # strip tabs/newlines; truncation is the formatter's job

printf '%s\t%s\t%s\t%s\t%s\n' "$state" "$(date +%s)" "$title" "$proj" "$pid" > "$file"
