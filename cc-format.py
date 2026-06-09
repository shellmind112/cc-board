#!/usr/bin/env python3
# 从 stdin 读 TSV（每行：状态 \t 项目 \t 你交代的活 \t 更新），
# 按"显示宽度"对齐成表（中文/emoji 算 2 格），每列之间固定 2 格间距。
import sys, unicodedata as u

def dw(s):  # 字符串的显示宽度
    return sum(2 if u.east_asian_width(c) in ('W', 'F') else 1 for c in s)

def pad(s, w):  # 右侧补空格到显示宽度 w
    return s + ' ' * max(0, w - dw(s))

def trunc(s, maxw):  # 按显示宽度安全截断（不切坏中文），超长加省略号
    if dw(s) <= maxw:
        return s
    out, w = '', 0
    for c in s:
        cw = 2 if u.east_asian_width(c) in ('W', 'F') else 1
        if w + cw > maxw - 1:
            break
        out += c
        w += cw
    return out + '…'

HEADER = ['状态', '项目', '你交代的活', '更新']
GAP = '  '  # 每列间距（统一 2 格）

rows = []
for line in sys.stdin:
    line = line.rstrip('\n')
    if not line:
        continue
    parts = line.split('\t')
    while len(parts) < 4:
        parts.append('')
    parts = parts[:4]
    parts[2] = trunc(parts[2], 30)   # "你交代的活"列最多 30 显示宽度
    rows.append(parts)

allrows = [HEADER] + rows
widths = [max(dw(r[i]) for r in allrows) for i in range(4)]

def fmt(r):
    return ' ' + GAP.join(pad(r[i], widths[i]) for i in range(4))

print(fmt(HEADER))
print(' ' + '─' * (sum(widths) + len(GAP) * 3))
if rows:
    for r in rows:
        print(fmt(r))
else:
    print('   （没有检测到正在运行的 CC）')
