# cc-board

> A live dashboard for all your running Claude Code sessions — see at a glance which is **running / waiting on you / done**, and which project each is in.

When you run several Claude Code sessions at once, it's hard to keep track — which one finished, which is waiting for you to approve something, which is still working? cc-board rolls them all into one table that refreshes every 2 seconds:

![cc-board demo](demo.gif)

---

## How it works

1. **`cc-report.sh`** (wired into Claude Code hooks) — on every state change, writes `state + project + the task you gave it` to `/tmp/cc-status/<terminal>`, keyed per terminal (pts) so each session stays separate.
2. **`cc-dashboard.sh`** — scans every live `claude` process, reads those status files, and re-renders the table every 2 seconds.
3. **`cc-format.py`** — aligns the columns by display width (CJK chars / emoji count as 2 cells; truncates without splitting wide characters).

---

## Requirements

- **Linux or WSL** + `bash` + `python3` (standard library only — **no third-party packages**; `python3` ships with most distros, so usually nothing to install).
- Optional, only if you want the one-key pop-up: **Windows Terminal** + **AutoHotkey v2**.

> ⚠️ **Linux / WSL only for now.** Session detection relies on `/proc`, `ps`, and pts terminals, so **macOS isn't supported yet** (PRs welcome).

---

## Install

**1. Clone the repo and copy the 3 scripts** into `~/.claude/` (any dir works; `~/.claude/` shown here). The `cp` below uses relative paths, so **run it from inside the repo folder**:
```bash
git clone https://github.com/shellmind112/cc-board.git
cd cc-board
cp cc-report.sh cc-dashboard.sh cc-format.py ~/.claude/
chmod +x ~/.claude/cc-report.sh ~/.claude/cc-dashboard.sh ~/.claude/cc-format.py
```

**2. Add 4 hooks to `~/.claude/settings.json`** (a hook = a command Claude Code runs for you at certain moments; these 4 make it report status on *prompt / working / waiting / done*):
```json
"hooks": {
  "UserPromptSubmit": [
    { "hooks": [ { "type": "command", "command": "bash ~/.claude/cc-report.sh running" } ] }
  ],
  "PostToolUse": [
    { "matcher": "*", "hooks": [ { "type": "command", "command": "bash ~/.claude/cc-report.sh running" } ] }
  ],
  "Notification": [
    { "hooks": [ { "type": "command", "command": "bash ~/.claude/cc-report.sh waiting" } ] }
  ],
  "Stop": [
    { "hooks": [ { "type": "command", "command": "bash ~/.claude/cc-report.sh done" } ] }
  ]
}
```

> ⚠️ **If your `settings.json` already has content:** don't paste over it — **merge** these 4 hooks into your existing `"hooks"` object (add the entries; only add a whole `"hooks": {...}` if you don't have one). JSON can't have duplicate keys.

**Concretely** — if your `settings.json` currently looks like this:
```json
{
  "model": "opus",
  "theme": "dark"
}
```
add the `hooks` block as the last key, and **don't forget the comma** after `"dark"`:
```json
{
  "model": "opus",
  "theme": "dark",
  "hooks": {
    "UserPromptSubmit": [ ... ],
    "PostToolUse":      [ ... ],
    "Notification":     [ ... ],
    "Stop":             [ ... ]
  }
}
```
A missing or extra comma makes the whole file invalid JSON (and Claude Code may refuse to start), so verify it right after editing:
```bash
python3 -m json.tool ~/.claude/settings.json   # prints the file if valid, errors out if not
```

**3. Run the dashboard** (any terminal):
```bash
bash ~/.claude/cc-dashboard.sh
```
That's it — open a few Claude Code sessions and they'll show up.

**Check it worked:** type any message into one of your Claude Code sessions; within ~2s that row should turn 🔴 running and the **Task** column should echo what you just typed. If every row stays ⚪ idle / `(not started)`, the hooks aren't firing — re-check step 2 (usually a JSON syntax slip, or the hooks weren't merged into your existing `"hooks"` object). Re-validate with `python3 -m json.tool ~/.claude/settings.json`.

---

## Optional: one-key pop-up on Windows

**A. A Windows Terminal profile** (gives the dashboard its own tab):
```json
{
  "name": "cc-board",
  "commandline": "wsl.exe -d Ubuntu -- bash ~/.claude/cc-dashboard.sh",
  "suppressApplicationTitle": true
}
```

**B. A global hotkey `Win+\`` to toggle the dashboard** (`ccboard.ahk`, needs AutoHotkey v2):
Run `ccboard.ahk`, then press `Win+\`` to summon the dashboard, press again to hide.
- It finds/toggles the dashboard window by the title `cc-board`, so make sure the WT profile `name` above is also `cc-board` (or edit the title in the ahk).
- If Windows Terminal already binds `Win+\`` to quake mode, remove that `globalSummon` `win+\`` binding in WT settings first so they don't fight over the key.
- `ccboard.ahk` also bundles a tiny two-window quick-switch (`Ctrl+1/2` to lock, `Alt+\`` to flip) — keep it or delete it.

---

## Known limitations

- Linux / WSL only (see above).
- With several Windows Terminal windows open, the ahk matches the dashboard by the title `cc-board`; if another window's title also contains that, it may match the wrong one.

## License

[MIT](LICENSE) — use / modify / sell freely, just keep the copyright notice.
