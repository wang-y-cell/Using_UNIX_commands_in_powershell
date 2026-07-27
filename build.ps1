<#
.SYNOPSIS
    将 src 安装到 $PROFILE 父目录下的 windows_use_linux_order，并写入 $PROFILE 加载路径。

.DESCRIPTION
    1. 复制仓库 src\ 全部文件到：$(Split-Path $PROFILE -Parent)\windows_use_linux_order\
    2. 在 $PROFILE 中写入（或更新）受标记保护的加载块，逐文件点源加载各函数。

.EXAMPLE
    .\build.ps1
#>
[CmdletBinding()]
param(
    [string]$InstallFolderName = 'windows_use_linux_order'
)

$ErrorActionPreference = 'Stop'

$markerBegin = '# >>> windows_use_linux_order BEGIN'
$markerEnd   = '# <<< windows_use_linux_order END'

$repoRoot = $PSScriptRoot
$srcRoot  = Join-Path $repoRoot 'src'
$loadScript = Join-Path $srcRoot 'load.ps1'

if (-not (Test-Path -LiteralPath $loadScript)) {
    throw "未找到源码: $loadScript"
}
if (-not $PROFILE) {
    throw '$PROFILE 未定义，无法安装。'
}

$profileDir = Split-Path -Parent $PROFILE
if (-not $profileDir) {
    throw "无法解析 `$PROFILE 父目录: $PROFILE"
}

$installRoot = Join-Path $profileDir $InstallFolderName

Write-Host "源码:     $srcRoot"
Write-Host "安装目录: $installRoot"
Write-Host "配置文件: $PROFILE"
Write-Host ''

# --- 1. 复制 src 到安装目录 ---
if (Test-Path -LiteralPath $installRoot) {
    Remove-Item -LiteralPath $installRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
Copy-Item -Path (Join-Path $srcRoot '*') -Destination $installRoot -Recurse -Force
Write-Host "已复制文件到: $installRoot"

# --- 2. 从 load.ps1 解析加载顺序 ---
$relPaths = [System.Collections.Generic.List[string]]::new()
$inArray = $false
foreach ($line in Get-Content -LiteralPath (Join-Path $installRoot 'load.ps1') -Encoding UTF8) {
    if ($line -match '\$script:WuloLoadOrder\s*=\s*@\(') {
        $inArray = $true
        continue
    }
    if ($inArray) {
        if ($line -match '^\s*\)\s*$') { break }
        if ($line -match "^\s*'([^']+)'\s*$") {
            $relPaths.Add($Matches[1])
        }
    }
}
if ($relPaths.Count -eq 0) {
    throw '无法从 load.ps1 解析加载顺序。'
}

foreach ($rel in $relPaths) {
    $p = Join-Path $installRoot $rel
    if (-not (Test-Path -LiteralPath $p)) {
        throw "安装不完整，缺少: $p"
    }
}

# --- 3. 生成 $PROFILE 加载块（展开每个函数文件的路径）---
$block = [System.Collections.Generic.List[string]]::new()
$block.Add($markerBegin)
$block.Add('# 由 build.ps1 自动生成；重新运行 build.ps1 可更新本段')
$block.Add("`$__wuloRoot = Join-Path (Split-Path `$PROFILE -Parent) '$InstallFolderName'")
foreach ($rel in $relPaths) {
    $escaped = $rel.Replace("'", "''")
    $block.Add(". (Join-Path `$__wuloRoot '$escaped')")
}
$block.Add('Remove-Variable __wuloRoot -ErrorAction SilentlyContinue')
$block.Add($markerEnd)

# --- 4. 写入 / 更新 $PROFILE ---
if (-not (Test-Path -LiteralPath $PROFILE)) {
    $parent = Split-Path -Parent $PROFILE
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Write-Host "已创建 `$PROFILE: $PROFILE"
}

$out = [System.Collections.Generic.List[string]]::new()
$skip = $false
$replaced = $false
foreach ($line in @(Get-Content -LiteralPath $PROFILE -ErrorAction SilentlyContinue)) {
    if ($line -eq $markerBegin) {
        $skip = $true
        foreach ($bl in $block) { $out.Add($bl) }
        $replaced = $true
        continue
    }
    if ($skip) {
        if ($line -eq $markerEnd) { $skip = $false }
        continue
    }
    $out.Add($line)
}
if (-not $replaced) {
    if ($out.Count -gt 0 -and $out[$out.Count - 1] -ne '') {
        $out.Add('')
    }
    foreach ($bl in $block) { $out.Add($bl) }
}

Set-Content -LiteralPath $PROFILE -Value ($out -join [Environment]::NewLine) -Encoding UTF8
Write-Host $(if ($replaced) { "已更新 `$PROFILE 中的加载块" } else { "已向 `$PROFILE 追加加载块" })

Write-Host ''
Write-Host '安装完成。重新打开 PowerShell 后生效；或当前会话执行:'
Write-Host "  . `"$(Join-Path $installRoot 'load.ps1')`""
Write-Host ''
Write-Host '已登记的函数文件:'
foreach ($rel in $relPaths) {
    Write-Host "  $(Join-Path $installRoot $rel)"
}
