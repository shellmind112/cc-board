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

- **Core (all you need):** Linux or WSL + `bash` + `python3` (standard library only — **no third-party packages, nothing to `pip install`**; `python3` ships with most distros).
- **Only for the *optional* global hotkey:** Windows Terminal + AutoHotkey v2. The dashboard itself does **not** need either of these.

> ⚠️ **Linux / WSL only for now.** Session detection relies on `/proc`, `ps`, and pts terminals, so **macOS isn't supported yet** (PRs welcome).

---

## Install (core — zero dependencies)

**1. Clone the repo and copy the 3 scripts** into `~/.claude/` (any dir works; `~/.claude/` shown here — it already exists if you've run Claude Code). The `cp` below uses relative paths, so **run it from inside the repo folder**:
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

> ℹ️ **About 🟡 waiting:** it comes from Claude Code's `Notification` hook, which mostly fires when a session needs your input (e.g. a permission prompt) — but it can also fire for other notifications, so 🟡 waiting means "probably needs you," not a hard guarantee.

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

That's the whole install. Next, open the dashboard.

---

## Open the dashboard

Three ways, from least to most setup. **The first needs nothing extra** — the others are just conveniences.

### Way 1 — run it and leave it open (simplest, zero setup)
```bash
bash ~/.claude/cc-dashboard.sh
```
Run it in any terminal/tab and **leave that tab open** — the table refreshes itself every 2 seconds, so you just glance at it whenever. This is all most people ever need.

**Check it worked:** type any message into one of your Claude Code sessions; within ~2s that row should turn 🔴 running and the **Task** column should echo what you just typed. If every row stays ⚪ idle / `(not started)`, the hooks aren't firing — re-check install step 2 (usually a JSON syntax slip, or the hooks weren't merged into your existing `"hooks"` object). Re-validate with `python3 -m json.tool ~/.claude/settings.json`.

### Way 2 — one-click tab in Windows Terminal (still zero dependency)
Add this profile to your Windows Terminal `settings.json` (inside `"profiles"` → `"list"`). Then **`📊 cc-board` appears in the new-tab `⌄` dropdown** — click it to open the dashboard in its own tab:
```json
{
  "name": "📊 cc-board",
  "commandline": "wsl.exe -d Ubuntu -- bash ~/.claude/cc-dashboard.sh",
  "suppressApplicationTitle": true
}
```
No software to install — it's a one-time config edit (mind the commas, same as the hooks step). It does **not** appear automatically; each machine adds the profile once.

---

## Optional (advanced): a global hotkey — needs AutoHotkey

> Only bother with this if you want to summon/hide the dashboard with a **single global key** from anywhere. It requires **AutoHotkey v2** installed and **kept running** — a real extra dependency. If you don't want that, Way 1 / Way 2 above already cover everyday use.

`ccboard.ahk` binds **Win+\`** to toggle the dashboard, and also bundles a tiny two-window quick-switch (`Ctrl+1` / `Ctrl+2` to lock two windows, **Alt+\`** to flip between them — delete that part of the script if you don't want it).

1. First add the **Way 2** Windows Terminal profile above — the hotkey opens the dashboard *through* that `📊 cc-board` profile.
2. Install **AutoHotkey v2**, then run `ccboard.ahk` (double-click it). To make it survive a reboot, drop a shortcut to it in your **Startup** folder (otherwise you re-launch it each boot).
3. Press **Win+\`** to summon the dashboard; press again to hide.

Notes:
- It finds the dashboard window by the **unique** title `📊 cc-board`. The 📊 is deliberate — it stops the hotkey from grabbing an ordinary terminal that just happens to sit in a folder named `cc-board` (whose Windows Terminal title would otherwise also be `cc-board`).
- **Win+\` already taken?** Windows Terminal's built-in *quake mode* may already own Win+\`. If pressing it drops down a plain terminal instead of cc-board, free the key by adding this entry to your WT `keybindings` (and deleting any `globalSummon` action), then **fully restart Windows Terminal**:
  ```json
  { "keys": "win+`", "id": null }
  ```
  Or simply change `#vkC0` in `ccboard.ahk` to a different key — e.g. `#+b::` for Win+Shift+B.

---

## Optional (advanced): Docker / sandboxed sessions

cc-board normally only sees claude sessions on the host. A claude running **inside a Docker container** lives in its own PID namespace, so the host `ps` can't see it. If you run claude in containers (e.g. a YOLO `--dangerously-skip-permissions` sandbox), you can have those show up too — tagged with a 🐳.

> Needs Docker, and it's **opt-in**: nothing changes unless you launch the dashboard with `CC_BOARD_DOCKER=1`. Anyone without Docker (or who doesn't opt in) pays nothing — this whole layer is skipped.

**How it works:** the dashboard asks `docker ps` which containers are running (= alive, since claude is the container's main process) and reads each one's status note from a shared host folder `/tmp/cc-status-docker/`. Liveness *is* the container — stop it and its row disappears within ~2s.

**Per container, three things:**

1. **Mount the shared notes folder** when you launch the container, so its note lands on the host (kept separate from host sessions, so a container can't touch them):
   ```bash
   docker run ... -v /tmp/cc-status-docker:/tmp/cc-status  your-image
   ```
2. **Put `cc-report.sh` + the 4 hooks inside the container** so its claude actually writes notes — bake them into your image. `cc-report.sh` auto-detects it's in a container (`/.dockerenv`) and keys its note by the container id, so no extra config:
   ```dockerfile
   COPY cc-report.sh /root/.claude/cc-report.sh        # adjust to your image's home dir
   # then add the same 4 hooks from Install step 2 to the container's ~/.claude/settings.json
   # (needs python3 in the image — most claude images already have it)
   ```
3. **Run the dashboard with the flag:**
   ```bash
   CC_BOARD_DOCKER=1 bash ~/.claude/cc-dashboard.sh
   ```

A containerized session then shows up as `🐳 <project>   <state>   <task>`, sorted in with the rest.

**Caveats:**
- First-class support assumes **claude is the container's main process (PID 1)** — the usual sandbox pattern. If claude is only one of several processes in a long-lived container, "container running" no longer implies "claude alive," so the row may linger.
- Leave the container's hostname at its default (the container id); a custom `--hostname` makes the note's key not match what `docker ps` reports.
- The container can read/write only that one shared notes folder — it can't reach the rest of your host. Still, a container *could* write junk notes onto your dashboard, so only enable this for containers you trust.

---

## License

[MIT](LICENSE) — use / modify / sell freely, just keep the copyright notice.
