# ln（简单函数 + $args）
# 支持：ln [-sf] TARGET LINK_NAME
# 例：ln -s .\README.md .\readme-link
#     ln -sf .\src\load.ps1 .\load-link
# 说明：-s 创建符号链接；无 -s 时创建硬链接（仅文件）。符号链接通常需要管理员或开发者模式。
function ln {
    $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
    $paths = @(Get-UnixPathArgs -Arguments $args)
    $paths = @(Expand-UnixGlob -Path $paths)

    $symbolic = $flags -contains 's'
    $force = $flags -contains 'f'

    if ($paths.Count -lt 2) {
        Write-Error 'ln: missing file operand'
        return
    }
    if ($paths.Count -gt 2) {
        Write-Error 'ln: only one TARGET and one LINK_NAME are supported'
        return
    }

    $target = $paths[0]
    $link = $paths[1]

    if (-not $symbolic -and -not (Test-Path -LiteralPath $target)) {
        Write-Error "ln: failed to access '${target}': No such file or directory"
        return
    }

    if (Test-Path -LiteralPath $link) {
        if (-not $force) {
            Write-Error "ln: failed to create link '${link}': File exists"
            return
        }
        try {
            Remove-Item -LiteralPath $link -Force -ErrorAction Stop
        } catch {
            Write-Error "ln: cannot replace '${link}': $($_.Exception.Message)"
            return
        }
    }

    $parent = Split-Path -Parent $link
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        Write-Error "ln: failed to create link '${link}': No such file or directory"
        return
    }

    try {
        if ($symbolic) {
            New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null
        } else {
            $targetItem = Get-Item -LiteralPath $target -Force
            if ($targetItem.PSIsContainer) {
                Write-Error "ln: '${target}': hard link not allowed for directories (use -s)"
                return
            }
            New-Item -ItemType HardLink -Path $link -Target $targetItem.FullName -ErrorAction Stop | Out-Null
        }
    } catch {
        Write-Error "ln: failed to create link '${link}': $($_.Exception.Message)"
    }
}
