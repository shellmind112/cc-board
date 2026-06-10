#!/usr/bin/env python3
# Read TSV from stdin (each line: state \t project \t task \t updated),
# align it into a table by DISPLAY width (CJK chars / emoji count as 2 cells),
# with a fixed 2-space gap between columns.
import sys, unicodedata as u

def dw(s):  # display width of a string
    return sum(2 if u.east_asian_width(c) in ('W', 'F') else 1 for c in s)

def pad(s, w):  # right-pad with spaces to display width w
    return s + ' ' * max(0, w - dw(s))

def trunc(s, maxw):  # safe truncate by display width (won't split a wide char), add ellipsis
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

HEADER = ['Status', 'Project', 'Task', 'Updated']
GAP = '  '  # fixed 2-space gap between columns

rows = []
for line in sys.stdin:
    line = line.rstrip('\n')
    if not line:
        continue
    parts = line.split('\t')
    while len(parts) < 4:
        parts.append('')
    parts = parts[:4]
    parts[2] = trunc(parts[2], 40)   # cap the "Task" column at 40 display cells
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
    print('   (no running Claude Code sessions)')
