#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook True

SetKeyDelay -1, -1

if !A_IsAdmin {
    MsgBox "请以管理员身份运行"
    ExitApp
}

SetWorkingDir A_ScriptDir

class Settings {
    static file := "AliceSettings.ini"
    static down := 250
    static up := 25

    static ReadInt(key, def) {
        try return Integer(IniRead(this.file, "click", key, def))
        catch
            return def   ; 文件缺失/节缺失/脏值 → 一律回落默认
    }

    static Load() {
        ; 下限 1: 0 会使 SetTimer 的负周期归零为"取消定时器"，导致 LButton 卡在按下（INV-1）
        this.down := Max(1, this.ReadInt("down_time", this.down))
        this.up := Max(1, this.ReadInt("up_time", this.up))
    }

    static Save() {
        IniWrite(String(this.down), this.file, "click", "down_time")
        IniWrite(String(this.up), this.file, "click", "up_time")
    }
}

App := { armed: false, clicking: false, phase: "down" }

ClickTick() {
    if !App.clicking || !GetKeyState("RButton", "P") {
        App.clicking := false
        Send("{LButton up}")
        return
    }
    if (App.phase = "down") {
        Send("{LButton down}")
        SetTimer ClickTick, -Settings.down
        App.phase := "up"
    } else {
        Send("{LButton up}")
        SetTimer ClickTick, -Settings.up
        App.phase := "down"
    }
}

StopClick() {
    App.clicking := false
    SetTimer ClickTick, 0
    Send("{LButton up}")
}

UpdateUI() {
    if App.armed {
        standbyBtn.Text := "停止待机"
        A_IconTip := "已开始待机，长按右键即可连点"
    } else {
        standbyBtn.Text := "开始待机"
        A_IconTip := "爱丽丝连点器：未待机"
    }
}

ChangeOnDownTime(GuiCtrl, *) {
    val := 0
    try val := Integer(GuiCtrl.Value)
    catch {
        val := 0
    }
    if (val < 1) {
        GuiCtrl.Value := String(Settings.down)
        ToolTip("按下时间需为不小于 1 的整数")
        SetTimer ClearTooltip, -1000
        return
    }
    Settings.down := val
    Settings.Save()
}

ChangeOnUpTime(GuiCtrl, *) {
    val := 0
    try val := Integer(GuiCtrl.Value)
    catch {
        val := 0
    }
    if (val < 1) {
        GuiCtrl.Value := String(Settings.up)
        ToolTip("抬起时间需为不小于 1 的整数")
        SetTimer ClearTooltip, -1000
        return
    }
    Settings.up := val
    Settings.Save()
}

ClearTooltip() {
    ToolTip()
}

ClickOnStandby(*) {
    if App.armed {
        App.armed := false
        StopClick()
    } else {
        App.armed := true
        Settings.Save()
    }
    UpdateUI()
}

Quit() {
    StopClick()
    Settings.Save()
    ExitApp
}

#HotIf App.armed
RButton:: {
    App.clicking := true
    App.phase := "down"
    SetTimer ClickTick, -1
    UpdateUI()
}
#HotIf

^1:: Quit()

Settings.Load()

myGui := Gui(, "爱丽丝连点器")
myGui.Add("Text", , "按下时间(ms)")
myGui.Add("Edit", " w360", String(Settings.down)).OnEvent("Change", ChangeOnDownTime)
myGui.Add("Text", , "抬起时间(ms)")
myGui.Add("Edit", " w360", String(Settings.up)).OnEvent("Change", ChangeOnUpTime)
standbyBtn := myGui.Add("Button", "Default w80 XP+100 YP+40", "开始待机")
standbyBtn.OnEvent("Click", ClickOnStandby)
myGui.Add("Button", "Default w80 XP+100", "退出").OnEvent("Click", (*) => Quit())

myGui.OnEvent("Close", (*) => Quit())
myGui.OnEvent("Escape", (*) => Quit())

A_TrayMenu.Delete()
A_TrayMenu.Add("退出", (*) => Quit())

UpdateUI()
myGui.Show()