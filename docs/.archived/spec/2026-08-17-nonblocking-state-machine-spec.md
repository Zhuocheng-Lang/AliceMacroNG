# SPEC — 非阻塞状态机范式（AliceMacroNG 设计规范）

状态: v1.0 草案
适用范围: 本仓库 `AliceMacro.ahk` 的重写，及任何同规模 AutoHotkey v2 单文件宏工具。
参考实现: 见本文档各节内联代码约定；完整实现以重写后的 `AliceMacro.ahk` 为准。

规范用词: **必须** / **不得** / **应当** / **禁止**（RFC 2119 风格）。

---

## 1. 核心原则：维度消除

本范式不逐个修 bug，而是消除 bug 赖以存在的结构维度：

> 原版所有缺陷共享三个根因——**阻塞式循环**、**布尔的私藏状态**、**单点退出**。
> 修复方式不是打补丁，而是更换范式，使这些 bug 无法被表达。

| 原版结构 | 本范式 | 被消除的维度 |
|---|---|---|
| `While + Sleep` 阻塞循环 | 定时器驱动两相状态机 | 热键缓冲、`Thread "Interrupt"` 补丁 |
| `ready` 布尔 + MsgBox | `App` 状态对象 + UI 投影 | 状态不可见、阻塞弹窗 |
| try/catch 反向初始化 ini | schema 自带默认值的读取 | 脏值静默脱钩 |
| 退出 = 被门控的单点 | 冗余退出系统，全部无条件 | 任务管理器剧本 |
| 手工传 exe | CI 编译 + SHA256 + 自动 release | 信任链裸奔 |
| 无实例保护 | `#SingleInstance Force` | 双开双倍连点 |

---

## 2. 架构分层

```
┌─────────────────────────────────────────┐
│ 分发层  CI 编译 → 校验和 → tag release    │  信任链
├─────────────────────────────────────────┤
│ UI 层   Gui / TrayTip / ToolTip          │  状态的投影（只读）
├─────────────────────────────────────────┤
│ 状态层  App 对象（armed/clicking/phase）  │  唯一状态 owner
├─────────────────────────────────────────┤
│ 引擎层  ClickTick 定时器状态机            │  非阻塞执行
├─────────────────────────────────────────┤
│ 设置层  Settings 类（ini 读写）           │  单一事实源
└─────────────────────────────────────────┘
```

依赖方向: 分发层独立；UI → 状态 → 引擎 → 设置。**不得**反向依赖（设置层不得感知 UI）。

---

## 3. 模块规范

### 3.1 设置层

- **必须**以 `class Settings` 静态类承载，作为配置的单一事实源；**禁止**散落的全局配置变量。
- **必须**为每个键定义 schema 默认值。读取统一走:

```ahk
static ReadInt(key, def) {
    try return Integer(IniRead(this.file, "click", key, def))
    catch return def   ; 文件缺失/节缺失/脏值 → 一律回落默认
}
```

- **不得**用 try/catch 包住整个 `LoadSettings` 再反向调用 `WriteSettings()` 初始化文件（原版反模式）。
- ini 节名**必须**有语义（如 `click`）；**禁止** `section1` 类脚手架名。
- 写入时机: 待机启动时 + 每次编辑框变更后（write-through）。

### 3.2 状态层

- 全部运行时状态**必须**住在一个 `App` 对象内: `armed`（是否待机）、`clicking`（是否连点中）、`phase`（`"down"`/`"up"`）。
- 任何状态变更后**必须**调用 `UpdateUI()`（见 3.4）。
- **禁止**用 MsgBox 表达运行状态——状态通知**必须**非阻塞。

### 3.3 引擎层（核心）

- 连点**必须**由单次定时器驱动的两相状态机实现:

```ahk
ClickTick() {
    if !App.clicking || !GetKeyState("RButton", "P") {
        App.clicking := false
        Send("{LButton up}")      ; 兜底抬起
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
```

- 每次 tick 只做三件事: 发一个事件、调度下一次、返回。热键线程存活时间**必须**在微秒级。
- **禁止**在热键内使用 `While + Sleep` 阻塞循环（原版反模式，是热键缓冲与 `Thread "Interrupt"` 补丁的根因）。
- 定时器**必须**用负值（单次）而非周期值，时长每次从 `Settings` 现读——参数编辑即时生效。
- `StopClick()` **必须**幂等: 清 `clicking`、`SetTimer ClickTick, 0`、兜底 `Send("{LButton up}")`。

### 3.4 UI 层

- UI 是状态的**投影**，**不得**持有状态。按钮文字、托盘提示由 `UpdateUI()` 从 `App` 派生。
- 待机按钮**必须**随状态切换文字（"开始待机" ⇄ "停止待机"），托盘提示同步。
- 非法输入处理**必须**"回弹": 将编辑框重置为真实生效值 + 短暂 ToolTip（≤1s）。**禁止**静默吞掉（UI 与实际脱钩）或弹阻塞框。

### 3.5 退出层

- 退出是**冗余系统**，不是单点。以下路径**必须**全部存在且无条件，全部汇聚到幂等的 `Quit()`（先 `StopClick()` → `Save()` → `ExitApp`）:
  1. 退出按钮
  2. 窗口 Close（X 按钮）
  3. 窗口 Escape
  4. 托盘菜单"退出"
  5. `^1` 热键
- `^1` **不得**置于任何 `#HotIf` 门控之内（原版反模式: 未待机时无热键可退）。
- `#HotIf App.armed` 只**允许**门控 `RButton` 一个热键。

### 3.6 实例与权限

- **必须** `#SingleInstance Force`。
- 管理员检查保持现状: 非管理员 → MsgBox 提示 → 退出。

### 3.7 分发层

- **必须**由 CI 完成: tag push (`v*`) → Ahk2Exe 编译（带 `Alice.ico`）→ 生成 SHA256 → 自动创建 release 附带 exe 与校验和文件。
- 每次 push **应当**执行编译，作为语法门禁（本项目无纯逻辑可单测，CI 编译即全部测试）。
- README **必须**包含校验命令说明。

---

## 4. 系统不变量

任何修改后，以下不变量**必须**全部成立:

| # | 不变量 | 由谁保证 |
|---|---|---|
| INV-1 | **按键安全**: 任何代码路径结束时 LButton 处于抬起状态 | tick 退出分支 + `StopClick()` 幂等 + `Quit()` 先停后出 |
| INV-2 | **状态一致**: UI 显示状态 ≡ 实际状态，任意时刻 | 所有变更过 `UpdateUI()`；非法输入回弹 |
| INV-3 | **退出可达**: 任意状态（含未待机、连点中）至少一条无条件退出路径可用 | `^1` 无门控 + Close/Escape/托盘 |
| INV-4 | **设置健壮**: 任何 ini 内容解析结果均为合法整数 | `ReadInt` 默认值兜底 |
| INV-5 | **单实例**: 同机同时最多一个进程 | `#SingleInstance Force` |
| INV-6 | **非阻塞**: 无热键线程存活超过一次 tick；长时行为只由 `SetTimer` 驱动 | 引擎层结构保证 |

---

## 5. 反模式清单（禁止引入）

| # | 反模式 | 原版后果 |
|---|---|---|
| AP-1 | 热键内 `While + Sleep` 循环 | `^1` 被缓冲至松开右键；需 `Thread "Interrupt"` 玄学补丁 |
| AP-2 | 布尔标志 + 阻塞 MsgBox 表达状态 | 状态不可见；弹窗打断工作流 |
| AP-3 | try/catch 整体包加载 + 反向写文件初始化 | 绕、脆，且脏字符串仍能进入全局 |
| AP-4 | 退出热键置于功能门控下 | 未待机 + 最小化 = 只能任务管理器 |
| AP-5 | 手工分发 exe、无校验和 | 要求 admin 却让用户全款预付信任 |
| AP-6 | 死代码、命名风格混用、无语义节名 | `Toggle` 从未使用；snake/camel 混用 |

---

## 6. KISS 纪律（明确不做的事）

- 不拆文件、不上框架。一个 `class Settings` 是复杂度上限。
- 不做多配置档、i18n、插件化、随机抖动（后者是产品决策，非工程决策）。
- 不换语言重写——对 ~105 行是负优化。
- 每次想"聪明一下"前**必须**验证 API 真的支持（教训: v2 的 `VarRef` 不支持类属性，泛化两个 Edit 回调的尝试被砍，写两份四行函数）。

---

## 7. 验证清单（代码审查）

本项目无法在本开发机（Linux）运行，验证 = 逐项审查:

- [ ] 全文无 `While` + `GetKeyState` 组合的阻塞循环（INV-6）
- [ ] `^1` 不在任何 `#HotIf` 块内（INV-3）
- [ ] 五条退出路径全部汇聚同一 `Quit()`（INV-3）
- [ ] 所有 `IniRead` 调用带默认值参数，且经 `Integer()` + try/catch（INV-4）
- [ ] `#SingleInstance Force` 存在（INV-5）
- [ ] 每个状态变更点后跟 `UpdateUI()`（INV-2）
- [ ] `Send("{LButton up}")` 出现在: tick 退出分支、`StopClick()`（INV-1）
- [ ] CI workflow 存在且 push 时编译通过（3.7）
