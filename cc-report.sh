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

# Pull cwd and prompt out of the JSON (no jq dependency; grep/sed the quoted value).
cwd=$(printf '%s' "$input" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
prompt=$(printf '%s' "$input" | grep -o '"prompt"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
[ -z "$cwd" ] && cwd="$PWD"
proj=$(basename "$cwd")

# title (the "Task" column): update it when we got a prompt; otherwise keep the existing one.
if [ -n "$prompt" ]; then
  title="$prompt"
else
  title=$(awk -F'\t' 'NR==1{print $3}' "$file" 2>/dev/null)
fi
title=$(printf '%s' "$title" | tr '\t\n\r' '   ')   # strip tabs/newlines; truncation is the formatter's job

printf '%s\t%s\t%s\t%s\t%s\n' "$state" "$(date +%s)" "$title" "$proj" "$pid" > "$file"
