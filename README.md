# 前言

适用于Nikke 爱丽丝的连点宏，可自设参数。长按鼠标右键即可连点。

### 叠甲：

使用任何脚本程序均有封号风险，请谨慎。

# 下载

在右边的 release 里有 CI 自动编译的 `AliceMacro.exe`，附带同名的 `.sha256` 校验和文件。需要管理员权限运行。

# 校验

下载后建议核对 SHA256，确认文件与 CI 编译产物一致：

```
certutil -hashfile AliceMacro.exe SHA256
```

把输出的哈希值与 release 里的 `AliceMacro.exe.sha256` 内容比对（Git Bash 用户也可以直接 `sha256sum -c AliceMacro.exe.sha256`）。

# 使用说明

参数设置完成后请去<https://kohi-click-test.bchrt.com/>测试一下，不超过38次点击应该就没问题。

点击"开始待机"后长按右键即可连点，再点一次可停止待机。

退出程序任选其一：退出按钮、右上角的叉、按 Esc、托盘菜单"退出"、或快捷键 `Ctrl+1`。
