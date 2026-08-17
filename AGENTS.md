# AGENTS.md

Single-file AutoHotkey v2 script (`AliceMacro.ahk`): a hold-right-button auto-clicker macro for the game Nikke (Alice). No build system, tests, CI, or dependencies. Distribution is a pre-compiled exe via GitHub Releases (icon: `Alice.ico`).

## Language / runtime constraints

- **AutoHotkey v2 only** (`#Requires AutoHotkey v2.0`). v1 syntax (legacy `If`, `%var%`, `SendInput` command style, `Gui, Add`) is incompatible — do not mix it in.
- Windows-only runtime. The script **exits unless run as admin** (elevated input is needed for the game). It cannot be run or tested on this Linux machine; verification is code review only.
- User-facing strings (GUI labels, MsgBox) and README are Simplified Chinese — keep new UI text consistent.

## Behavioral gotchas (from the code)

- The GUI has no Close handler: clicking X does **not** exit; the process stays in background. Real exit paths are the 退出 button or the `^1` hotkey. Preserve at least one working exit.
- `#HotIf ready` gates the RButton macro and `^1`; they are inactive until the user clicks 开始待机.
- Settings persist to `AliceSettings.ini` next to the script (`SetWorkingDir A_ScriptDir`), read as strings and parsed via `Integer()` in try/catch. `*.ini` and `*.exe` are gitignored — never commit them.

## Version control

- Repo is colocated jj + git (`.jj/` alongside `.git/`). Plain `git` commands work; prefer `jj` for history rewriting/amending.
