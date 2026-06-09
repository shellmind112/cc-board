#!/bin/bash
# 被 CC 的 hook 调用：把"当前这个 CC 会话"的状态写到 /tmp/cc-status/<pts> 文件里，供看板读取。
# 参数 $1 = 状态：running（运行中）/ waiting（等你确认）/ done（完成）
# CC 会在 stdin 传一段 JSON 上下文（含 cwd；UserPromptSubmit 还含你发的 prompt）。
state="${1:-running}"
input=$(cat 2>/dev/null)

# 顺着进程父链找到本会话的 claude 进程，取它挂的终端(pts)当唯一标识——
# 这样每个 tab 的 CC 各写各的文件，互不覆盖。
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

# 从 JSON 取 cwd 和 prompt（本环境没装 jq，用 grep/sed 解析；取双引号里的值）
cwd=$(printf '%s' "$input" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
prompt=$(printf '%s' "$input" | grep -o '"prompt"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
[ -z "$cwd" ] && cwd="$PWD"
proj=$(basename "$cwd")

# title（看板上"你交代的活"）：拿到 prompt 就更新；否则保留文件里原来的 title
if [ -n "$prompt" ]; then
  title="$prompt"
else
  title=$(awk -F'\t' 'NR==1{print $3}' "$file" 2>/dev/null)
fi
title=$(printf '%s' "$title" | tr '\t\n\r' '   ')   # 去掉制表/换行；长度截断交给排版器，避免切坏中文

printf '%s\t%s\t%s\t%s\t%s\n' "$state" "$(date +%s)" "$title" "$proj" "$pid" > "$file"
