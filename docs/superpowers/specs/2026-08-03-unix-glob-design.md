# Unix 风格路径通配符展开 — 设计说明

日期：2026-08-03  
状态：待实现

## 背景

当前命令通过 `Get-UnixPathArgs` 取出路径后，一律使用 `-LiteralPath` 访问文件系统。因此 `*.txt`、`src/**/*.ps1` 等会被当成字面路径，无法像 Linux shell 那样展开。

## 目标

- 为带路径参数的命令增加通配符展开能力
- 通配逻辑集中在 `common` 独立函数中，各命令显式调用
- 无匹配时静默跳过（该参数不产生结果）
- 无通配符时行为与现有实现完全一致

## 非目标

- 不在 PowerShell 提示符层做全局 glob（仅本项目函数内展开）
- 不改变 `find -name` / `grep` 正则等「模式参数」的语义
- 不为 `which` 做文件系统 glob（参数是命令名）

## 需求摘要

| 项 | 约定 |
|----|------|
| 语法 | `*`、`?`、`[abc]` / `[0-9]`、路径段 `**`（任意层级） |
| 无匹配 | 静默（贡献 0 条路径） |
| 接入范围 | 所有带路径/文件参数的命令（见下文清单） |
| 字面路径不存在 | 仍由各命令原有逻辑报错 |

## 方案

采用**独立展开函数 + 各命令显式调用**（不把展开并入 `Get-UnixPathArgs`），避免路径解析与模式参数耦合。

## 公共 API

文件：`src/common/Expand-UnixGlob.ps1`  
在 `load.ps1` 的 common 段加载（位于现有 Unix 参数辅助之后、各命令之前）。

### `Test-UnixGlobPattern`

- 入参：`[string]$Pattern`
- 返回：`[bool]` — 是否含通配符（`*`、`?`、`[...]`，或路径段 `**`）

### `Expand-UnixGlob`

- 入参：`[string[]]$Path`
- 返回：`[string[]]` — 展开后的路径列表
- 行为：
  1. 对每个输入路径：若**不含**通配符 → 原样加入结果（不做存在性检查）
  2. 若**含**通配符 → 按规则匹配文件系统；有匹配则加入（建议返回可被后续 `-LiteralPath` 使用的路径字符串）；无匹配则跳过
  3. 多个输入依次展开后拼接
  4. 普通 `*` / `?` / `[]` 只匹配单层目录项；`**` 可跨越任意层级目录
  5. 展开过程中不可读目录等错误尽量 `SilentlyContinue`，不中断整次展开
  6. 大小写跟随 Windows 文件系统惯例（通常不区分）

## 命令接入

统一模式：

```powershell
$paths = @(Get-UnixPathArgs -Arguments $args)
$paths = @(Expand-UnixGlob -Path $paths)
```

手工从 `$args` 解析出路径列表的命令（如 `head` / `tail` / `tree` / `find` 的 roots、`grep` 的文件参数），在得到路径列表后同样调用 `Expand-UnixGlob`。

### 需要接入

`ls`、`rm`、`cp`、`mv`、`cat`、`head`、`tail`、`wc`、`sort`、`uniq`、`tee`、`touch`、`mkdir`、`du`、`df`、`tree`、`diff`、`ln`、`basename`、`dirname`、`grep`（仅文件参数）、`find`（仅搜索根路径）

### 明确不展开

| 场景 | 原因 |
|------|------|
| `which` | 参数是命令名，不是文件路径 |
| `grep` 的正则模式 | 模式字面量 |
| `find -name` / `-iname` 等模式 | 已有独立通配逻辑 |
| `ls` 无路径参数 | 默认当前目录，无需展开 |

### 特殊约定

- `cp` / `mv`：源与目标（最后一参）都可展开；多匹配后仍走现有「多源时目标必须是目录」等校验
- 展开后结果为空且命令要求至少一个操作数：沿用原有 `missing operand` 类错误（可接受）

## 错误处理

- 通配无匹配 → 静默
- 字面路径缺失 → 各命令原报错
- 展开 I/O 失败 → 尽量静默跳过该分支，不抛致命错误

## 文档

在 `COMMANDS.md` 总览附近增加通配符说明：支持的语法、静默无匹配、以及 `find -name` / `grep` 模式不经此展开。

## 验收标准

1. `rm *.nomatch`（无匹配）→ 不因通配本身报错；若展开后无路径，可出现原有 `missing operand`
2. `cat *.ps1`（有匹配）→ 输出所有匹配文件内容
3. 含 `**` 的模式（如 `src/**/*.ps1`）→ 能匹配多层目录下的文件
4. `grep foo *.txt` → 仅对匹配到的文件搜索；`grep` 模式字符串不被展开
5. `find . -name "*.ps1"` → `-name` 行为不变
6. 无通配符的旧用法行为与现在一致

## 实现顺序建议

1. 实现并加载 `Expand-UnixGlob.ps1`（含 `Test-UnixGlobPattern`）
2. 批量接入使用 `Get-UnixPathArgs` 的命令
3. 接入手工解析路径的命令（`head`/`tail`/`tree`/`find`/`grep` 等）
4. 更新 `COMMANDS.md`
5. 按验收标准手工验证
