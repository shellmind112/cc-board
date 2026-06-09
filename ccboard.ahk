#Requires AutoHotkey v2.0

; 初始化变量
global Window1 := 0
global Window2 := 0

; 录制第一个窗口：按 Ctrl + 1
^1:: {
    global Window1 := WinExist("A")
    TrayTip "已成功锁定窗口 1！", "窗口锁定"
}

; 录制第二个窗口：按 Ctrl + 2
^2:: {
    global Window2 := WinExist("A")
    TrayTip "已成功锁定窗口 2！", "窗口锁定"
}

; 专属切换键：按 Alt + ` (数字1左边那个键)
!`:: {
    global Window1, Window2
    if (!Window1 || !Window2) {
        MsgBox "请先使用 Ctrl+1 和 Ctrl+2 锁定两个窗口！", "提示"
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

; ===== Win + ` 开/收 CC看板 =====
#vkC0:: {
    win := "CC看板 ahk_exe WindowsTerminal.exe"
    if WinExist(win) {
        if WinActive(win)
            WinMinimize(win)
        else
            WinActivate(win)
    } else {
        Run 'wt.exe -w ccboard -p "CC看板"'
    }
}