<#
.SYNOPSIS
    从 $PROFILE 中移除 Using_UNIX_commands_in_powershell 加载块，并删除安装目录。

.DESCRIPTION
    1. 删除 $PROFILE 中 # >>> Using_UNIX_commands_in_powershell BEGIN 到 # <<< Using_UNIX_commands_in_powershell END 整段
    2. 同时清理旧版 windows_use_linux_order 标记块（若仍存在）
    3. 删除安装目录 Using_UNIX_commands_in_powershell\（以及旧版 windows_use_linux_order\）

.EXAMPLE
    .\remove.ps1
#>
[CmdletBinding()]
param(
    [string]$InstallFolderName = 'Using_UNIX_commands_in_powershell',
    [switch]$KeepInstallFolder
)

$ErrorActionPreference = 'Stop'

$markerBegin = '# >>> Using_UNIX_commands_in_powershell BEGIN'
$markerEnd   = '# <<< Using_UNIX_commands_in_powershell END'
$legacyMarkerBegin = '# >>> windows_use_linux_order BEGIN'
$legacyMarkerEnd   = '# <<< windows_use_linux_order END'
$legacyFolderName  = 'windows_use_linux_order'

if (-not $PROFILE) {
    throw '$PROFILE 未定义，无法卸载。'
}

$profileDir = Split-Path -Parent $PROFILE
if (-not $profileDir) {
    throw "无法解析 `$PROFILE 父目录: $PROFILE"
}

$installRoot = Join-Path $profileDir $InstallFolderName
$legacyInstall = Join-Path $profileDir $legacyFolderName

Write-Host "配置文件: $PROFILE"
Write-Host "安装目录: $installRoot"
Write-Host ''

# --- 1. remove marker blocks from profile ---
$removedBlock = $false
if (-not (Test-Path -LiteralPath $PROFILE)) {
    Write-Host '配置文件不存在，跳过加载块清理。' -ForegroundColor DarkGray
} else {
    $out = [System.Collections.Generic.List[string]]::new()
    $skip = $false
    $skipEnd = $null
    foreach ($line in @(Get-Content -LiteralPath $PROFILE)) {
        if (-not $skip -and ($line -eq $markerBegin -or $line -eq $legacyMarkerBegin)) {
            $skip = $true
            $skipEnd = if ($line -eq $markerBegin) { $markerEnd } else { $legacyMarkerEnd }
            $removedBlock = $true
            continue
        }
        if ($skip) {
            if ($line -eq $skipEnd) {
                $skip = $false
                $skipEnd = $null
            }
            continue
        }
        $out.Add($line)
    }

    if ($skip) {
        throw "检测到开始标记但缺少结束标记，已中止写入以避免损坏 `$PROFILE。请手动检查: $PROFILE"
    }

    if ($removedBlock) {
        while ($out.Count -gt 0 -and [string]::IsNullOrWhiteSpace($out[$out.Count - 1])) {
            $out.RemoveAt($out.Count - 1)
        }
        Set-Content -LiteralPath $PROFILE -Value ($out -join [Environment]::NewLine) -Encoding UTF8
        Write-Host "已从 `$PROFILE 删除加载块（含新旧标记，若存在）"
    } else {
        Write-Host '未在 $PROFILE 中找到加载块标记，无需删除。' -ForegroundColor DarkGray
    }
}

# --- 2. remove install folders ---
if ($KeepInstallFolder) {
    Write-Host '已指定 -KeepInstallFolder，保留安装目录。' -ForegroundColor DarkGray
} else {
    foreach ($dir in @($installRoot, $legacyInstall) | Select-Object -Unique) {
        if (Test-Path -LiteralPath $dir) {
            Remove-Item -LiteralPath $dir -Recurse -Force
            Write-Host "已删除安装目录: $dir"
        }
    }
    if (-not (Test-Path -LiteralPath $installRoot) -and -not (Test-Path -LiteralPath $legacyInstall)) {
        # 两者都不存在时给一个提示（避免完全无输出）
        if (-not $removedBlock) {
            Write-Host '安装目录不存在，跳过。' -ForegroundColor DarkGray
        }
    }
}

Write-Host ''
Write-Host '卸载完成。重新打开 PowerShell 后生效（当前会话中的函数/别名仍在，直到关闭窗口）。'
