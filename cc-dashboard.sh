#!/bin/bash
# CC 状态看板：扫描所有活着的 claude 进程（= 你开了几个 CC 的真相），
# 用 /tmp/cc-status/ 里的状态文件补上"在跑/等你/完成 + 你交代的活"，
# 没动过的 CC 显示为"空闲"。排版交给 cc-format.py 按显示宽度对齐。
# 传 --once 只画一帧（测试用）。
DIR=/tmp/cc-status
FMT="$HOME/.claude/cc-format.py"

rows() {  # 产出 TSV：状态 \t 项目 \t 你交代的活 \t 更新
  local now pid tty id file s t ti pr fpid state ts title proj label age agestr
  now=$(date +%s)
  while read -r pid tty; do
    [ -z "$pid" ] && continue
    id=$(printf '%s' "$tty" | tr '/' '-')          # pts/8 -> pts-8
    file="$DIR/$id"
    state=idle; title="（未开始）"; ts=""; proj=""
    if [ -f "$file" ]; then
      IFS=$'\t' read -r s t ti pr fpid < "$file"
      if [ -n "$fpid" ] && kill -0 "$fpid" 2>/dev/null; then   # 写状态的进程还活着才采信
        state="$s"; ts="$t"; title="$ti"; proj="$pr"
      fi
    fi
    [ -z "$proj" ] && proj=$(basename "$(readlink /proc/$pid/cwd 2>/dev/null)" 2>/dev/null)
    [ -z "$proj" ] && proj="?"
    case "$state" in
      running) label="🔴 运行中" ;;
      waiting) label="🟡 等你确认" ;;
      done)    label="✅ 完成" ;;
      idle)    label="⚪ 空闲" ;;
      *)       label="◽ $state" ;;
    esac
    if [ -n "$ts" ]; then
      age=$(( now - ts ))
      if   [ "$age" -lt 60 ];   then agestr="${age}s前"
      elif [ "$age" -lt 3600 ]; then agestr="$((age/60))m前"
      else                           agestr="$((age/3600))h前"; fi
    else agestr="—"; fi
    printf '%s\t%s\t%s\t%s\n' "$label" "$proj" "$title" "$agestr"
  done < <(ps -eo pid=,tty=,comm= 2>/dev/null | awk '$3=="claude" && $2 ~ /^pts/ && !seen[$2]++ {print $1, $2}')
}

render() {
  printf ' CC 看板   每 2 秒刷新 · Ctrl+C 退出\n'
  rows | python3 "$FMT"
}

if [ "$1" = "--once" ]; then render; exit 0; fi
while true; do clear; render; sleep 2; done
