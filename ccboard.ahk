#Requires AutoHotkey v2.0

; ===== Win + ` : toggle (summon / hide) the cc-board dashboard =====
; Finds the dashboard window by its title "cc-board"; launches it if not open.
; Make sure your Windows Terminal profile that runs cc-dashboard.sh is named "cc-board".
#vkC0:: {
    win := "cc-board ahk_exe WindowsTerminal.exe"
    if WinExist(win) {
        if WinActive(win)
            WinMinimize(win)        ; visible & focused -> hide
        else
            WinActivate(win)        ; open but in the back -> bring to front
    } else {
        Run 'wt.exe -w ccboard -p "cc-board"'   ; not open -> launch it
    }
}

; ===== Bonus: quick-switch between two windows (handy alongside cc-board) =====
; Ctrl+1 / Ctrl+2 to lock two windows, Alt+` to flip between them. Delete if unwanted.
global Window1 := 0
global Window2 := 0

^1:: {
    global Window1 := WinExist("A")
    TrayTip "Window 1 locked", "cc-board"
}

^2:: {
    global Window2 := WinExist("A")
    TrayTip "Window 2 locked", "cc-board"
}

!`:: {
    global Window1, Window2
    if (!Window1 || !Window2) {
        MsgBox "Lock two windows first with Ctrl+1 and Ctrl+2.", "cc-board"
        return
    }
    CurrentWindow := WinExist("A")
    if (CurrentWindow == Window1) {
        if WinExist("ahk_id " Window2)
            WinActivate("ahk_id " Window2)
    } else {
        if WinExist("ahk_id " Window1)
            WinActivate("ahk_id " Window1)
    }
}
