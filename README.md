# windows_use_linux_order

在 Windows PowerShell 中使用接近 Linux / Ubuntu 习惯的常用命令与终端体验。

本项目通过一个 PowerShell 脚本（`windows_use_linux_order.ps1`），提供：

- Linux 风格的 `ls` / `ll`（彩色、横向多列、长列表、可读大小）
- Linux 风格的 `find`
- 常用文件命令：`pwd`、`mkdir`、`touch`、`rm`、`cp`、`mv`
- 类似 `user@host:path $` 的彩色提示符

命令参数与行为尽量贴近 GNU/Linux 常见用法（支持 `-al`、`-rf` 等组合开关）。完整命令说明见 [COMMANDS.md](COMMANDS.md)。

## 环境要求

- Windows 10 / 11
- Windows PowerShell 5.1，或 PowerShell 7+
- 建议使用支持 ANSI 真彩色的终端（Windows Terminal、新版 PowerShell 控制台）

## 快速开始

### 1. 获取脚本

将仓库克隆或下载到本地，例如：

```powershell
git clone <你的仓库地址>
cd windows_use_linux_order
```

记住脚本的完整路径，例如：

```text
F:\wy\windows_use_linux_order\windows_use_linux_order.ps1
```

### 2. 临时加载（当前会话）

在 PowerShell 中执行：

```powershell
. F:\wy\windows_use_linux_order\windows_use_linux_order.ps1
```

注意前面的点号 `.`（点源加载），这样函数和别名才会进入当前会话。

加载成功后可直接试用：

```powershell
ls
ll
pwd
find . -name "*.ps1"
```

关闭该窗口后配置会失效；需要长期生效请看下一节。

### 3. 永久加载（推荐：写入 PowerShell 配置文件）

先查看当前配置文件路径：

```powershell
$PROFILE
```

常见路径类似：

```text
C:\Users\<用户名>\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
```

或 PowerShell 7：

```text
C:\Users\<用户名>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
```

若文件不存在，可创建：

```powershell
if (!(Test-Path -Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force
}
notepad $PROFILE
```

在配置文件末尾添加一行（路径改成你的实际路径）：

```powershell
. "F:\wy\windows_use_linux_order\windows_use_linux_order.ps1"
```

保存后，**重新打开**一个 PowerShell 窗口即可自动生效。

也可一行追加：

```powershell
Add-Content -Path $PROFILE -Value '. "F:\wy\windows_use_linux_order\windows_use_linux_order.ps1"'
```

### 4. 若提示“无法加载，因为在此系统上禁止运行脚本”

当前执行策略可能过严。可仅对当前用户放开（推荐）：

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

然后重新打开 PowerShell，再加载脚本或依赖 `$PROFILE`。

也可不改策略，仅对当前会话绕过：

```powershell
powershell -ExecutionPolicy Bypass -NoExit -File "F:\wy\windows_use_linux_order\windows_use_linux_order.ps1"
```

注意：`-File` 会在脚本结束后退出（除非加 `-NoExit`）；若希望函数留在交互会话里，仍建议用点源加载：

```powershell
powershell -NoExit -Command ". 'F:\wy\windows_use_linux_order\windows_use_linux_order.ps1'"
```

## 验证是否生效

```powershell
Get-Command ls, ll, find, mkdir, touch, rm, cp, mv, pwd
ls -alh
ll
find . -type f -name "*.ps1"
```

提示符应类似：

```text
windows@PS:F:\wy\windows_use_linux_order $
```

（提示符中的用户名目前写死在脚本的 `prompt` 函数里，可按需自行修改。）

## 文档

| 文档 | 说明 |
|------|------|
| [COMMANDS.md](COMMANDS.md) | 本项目提供的全部命令、参数与示例 |

## 说明与限制

- 本项目是对常用 Linux 命令的**子集模拟**，并非完整 GNU coreutils / findutils。
- `find` 的 `-ctime` 在 Windows 上用创建时间近似（系统无 Unix 语义上的 ctime）。
- `ls` 颜色规则为简化版（目录 / 可执行脚本 / 压缩包 / 其他）。
- 部分命令会覆盖 PowerShell 自带别名（如 `ls`、`mkdir`、`pwd`、`rm`、`cp`、`mv`）。若不需要，可从 `$PROFILE` 中移除对本脚本的引用。

## 卸载

从 `$PROFILE` 中删除加载本脚本的那一行，保存后重新打开 PowerShell 即可。

## 许可证

若仓库未单独声明许可证，默认仅供个人学习与自用；二次分发请自行补充许可说明。
