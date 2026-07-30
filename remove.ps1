<#
.SYNOPSIS
    从 $PROFILE 中移除 windows_use_linux_order 加载块，并删除安装目录。

.DESCRIPTION
    1. 删除 $PROFILE 中 # >>> windows_use_linux_order BEGIN 到 # <<< windows_use_linux_order END 整段
    2. 删除 $(Split-Path $PROFILE -Parent)\windows_use_linux_order\ 安装目录（若存在）

.EXAMPLE
    .\remove.ps1
#>
[CmdletBinding()]
param(
    [string]$InstallFolderName = 'windows_use_linux_order',
    [switch]$KeepInstallFolder
)

$ErrorActionPreference = 'Stop'

$markerBegin = '# >>> windows_use_linux_order BEGIN'
$markerEnd   = '# <<< windows_use_linux_order END'

# 如果$PROFILE未定义，则抛出错误
if (-not $PROFILE) {
    throw '$PROFILE 未定义，无法卸载。'
}

# 如果$PROFILE的父目录未定义，则抛出错误
$profileDir = Split-Path -Parent $PROFILE
if (-not $profileDir) {
    throw "无法解析 `$PROFILE 父目录: $PROFILE"
}

# 获得安装目录
$installRoot = Join-Path $profileDir $InstallFolderName

# 输出配置文件和安装目录
Write-Host "配置文件: $PROFILE"
Write-Host "安装目录: $installRoot"
Write-Host ''

# --- 1. remove marker block from profile ---
$removedBlock = $false
# 如果配置文件不存在，则输出提示信息
if (-not (Test-Path -LiteralPath $PROFILE)) {
    Write-Host '配置文件不存在，跳过加载块清理。' -ForegroundColor DarkGray
} else {
    $out = [System.Collections.Generic.List[string]]::new() #创建一个列表，用于存放配置文件的内容
    $skip = $false #是否跳过,找到开始标记设置为true，找到结束标记设置为false
    foreach ($line in @(Get-Content -LiteralPath $PROFILE)) {
        if ($line -eq $markerBegin) { #如果当前行是开始标记，则设置跳过标志
            $skip = $true
            $removedBlock = $true #设置删除标志
            continue #继续下一行
        }
        if ($skip) { #如果跳过标志为true，则继续下一行
            if ($line -eq $markerEnd) { $skip = $false } #如果当前行是结束标记，则设置跳过标志为false
            continue
        }
        $out.Add($line) #将当前行添加到列表中
    }
    # 最终的结果是，out是这个$PROFILE文件排除掉加载块后的内容

    if ($skip) { #结束的时候发现跳过标志为true，说明没有找到结束标记
        throw "检测到开始标记但缺少结束标记，已中止写入以避免损坏 `$PROFILE。请手动检查: $PROFILE"
    }

    if ($removedBlock) { # 确实进入删除代码块，而不是没有找到开始标记
        # out的数量大于0，并且最后一行是空行
        while ($out.Count -gt 0 -and [string]::IsNullOrWhiteSpace($out[$out.Count - 1])) {
            # 删除最后一行空行
            $out.RemoveAt($out.Count - 1)
        }
        # 将列表中的内容写入配置文件,因为out没有加载块，所以直接写入
        Set-Content -LiteralPath $PROFILE -Value ($out -join [Environment]::NewLine) -Encoding UTF8
        Write-Host "已从 `$PROFILE 删除加载块（# >>> windows_use_linux_order BEGIN ... # <<< windows_use_linux_order END）"
    } else {
        Write-Host '未在 $PROFILE 中找到加载块标记，无需删除。' -ForegroundColor DarkGray
    }
}

# --- 2. remove install folder ---
if ($KeepInstallFolder) {
    Write-Host '已指定 -KeepInstallFolder，保留安装目录。' -ForegroundColor DarkGray
} elseif (Test-Path -LiteralPath $installRoot) {
    Remove-Item -LiteralPath $installRoot -Recurse -Force
    Write-Host "已删除安装目录: $installRoot"
} else {
    Write-Host '安装目录不存在，跳过。' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host '卸载完成。重新打开 PowerShell 后生效（当前会话中的函数/别名仍在，直到关闭窗口）。'
