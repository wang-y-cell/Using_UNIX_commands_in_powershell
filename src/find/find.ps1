# Linux 风格 find（-name/-iname/-type/-mtime/-size ...）
# 简单函数：从 $args 解析路径与带值选项（-mtime -1 等值不能当短选项拆）
function find {
    <#
    .SYNOPSIS
        Linux 风格的文件查找（常用子集）
    .EXAMPLE
        find . -name "*.txt"
        find . -iname "*.TXT" -type f
        find . -type d -mtime -1
        find . -type f -size +100M
    #>

    $argv = @($args)
    $path = '.'
    $name = $null
    $iname = $null
    $type = $null
    $mtime = $null
    $mmin = $null
    $atime = $null
    $ctime = $null
    $size = $null
    $hasMtime = $false
    $hasMmin = $false
    $hasAtime = $false
    $hasCtime = $false
    $hasSize = $false

    $i = 0
    while ($i -lt $argv.Count) {
        $tok = [string]$argv[$i]
        if ($tok -eq '-name') {
            if ($i + 1 -ge $argv.Count) { Write-Error 'find: missing argument to `-name`'; return }
            $name = [string]$argv[$i + 1]
            $i += 2
            continue
        }
        if ($tok -eq '-iname') {
            if ($i + 1 -ge $argv.Count) { Write-Error 'find: missing argument to `-iname`'; return }
            $iname = [string]$argv[$i + 1]
            $i += 2
            continue
        }
        if ($tok -eq '-type') {
            if ($i + 1 -ge $argv.Count) { Write-Error 'find: missing argument to `-type`'; return }
            $type = [string]$argv[$i + 1]
            $i += 2
            continue
        }
        if ($tok -eq '-mtime') {
            if ($i + 1 -ge $argv.Count) { Write-Error 'find: missing argument to `-mtime`'; return }
            $mtime = [string]$argv[$i + 1]
            $hasMtime = $true
            $i += 2
            continue
        }
        if ($tok -eq '-mmin') {
            if ($i + 1 -ge $argv.Count) { Write-Error 'find: missing argument to `-mmin`'; return }
            $mmin = [string]$argv[$i + 1]
            $hasMmin = $true
            $i += 2
            continue
        }
        if ($tok -eq '-atime') {
            if ($i + 1 -ge $argv.Count) { Write-Error 'find: missing argument to `-atime`'; return }
            $atime = [string]$argv[$i + 1]
            $hasAtime = $true
            $i += 2
            continue
        }
        if ($tok -eq '-ctime') {
            if ($i + 1 -ge $argv.Count) { Write-Error 'find: missing argument to `-ctime`'; return }
            $ctime = [string]$argv[$i + 1]
            $hasCtime = $true
            $i += 2
            continue
        }
        if ($tok -eq '-size') {
            if ($i + 1 -ge $argv.Count) { Write-Error 'find: missing argument to `-size`'; return }
            $size = [string]$argv[$i + 1]
            $hasSize = $true
            $i += 2
            continue
        }
        if ($tok.StartsWith('-')) {
            Write-Error "find: unknown predicate `$tok'"
            return
        }
        $path = $tok
        $i++
    }

    if ($type -and $type -notin @('f', 'd', 'l', 'F', 'D', 'L')) {
        Write-Error "find: invalid argument `$type' to `-type'"
        return
    }

    if (-not (Test-Path -LiteralPath $path)) {
        Write-Error "路径不存在: $path"
        return
    }

    $sizeFilter = $null
    if ($hasSize) {
        $sizeFilter = Convert-FindSizeSpec -Spec ([string]$size)
    }

    $mtimeFilter = if ($hasMtime) { Convert-FindTimeSpec -Spec ([string]$mtime) } else { $null }
    $mminFilter  = if ($hasMmin)  { Convert-FindTimeSpec -Spec ([string]$mmin) }  else { $null }
    $atimeFilter = if ($hasAtime) { Convert-FindTimeSpec -Spec ([string]$atime) } else { $null }
    $ctimeFilter = if ($hasCtime) { Convert-FindTimeSpec -Spec ([string]$ctime) } else { $null }

    $namePattern = $null
    if ($name) {
        $namePattern = [Management.Automation.WildcardPattern]::new($name, [Management.Automation.WildcardOptions]::None)
    }
    $inamePattern = $null
    if ($iname) {
        $inamePattern = [Management.Automation.WildcardPattern]::new(
            $iname,
            [Management.Automation.WildcardOptions]::IgnoreCase
        )
    }

    $typeKey = if ($type) { $type.ToLowerInvariant() } else { $null }
    $now = Get-Date

    $root = Get-Item -LiteralPath $path -Force
    $items = @($root) + @(
        Get-ChildItem -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
    )

    foreach ($item in $items) {
        # --- 类型 ---
        if ($typeKey) {
            $isLink = Test-FindIsSymlink -Item $item
            $isDir = $item.PSIsContainer -and -not $isLink
            $isFile = -not $item.PSIsContainer -and -not $isLink
            $matchType = switch ($typeKey) {
                'f' { $isFile }
                'd' { $isDir }
                'l' { $isLink }
                default { $true }
            }
            if (-not $matchType) { continue }
        }

        # --- 名称 ---
        if ($namePattern -and -not $namePattern.IsMatch($item.Name)) { continue }
        if ($inamePattern -and -not $inamePattern.IsMatch($item.Name)) { continue }

        # --- 时间 ---
        if ($mtimeFilter) {
            $ageDays = ($now - $item.LastWriteTime).TotalDays
            if (-not (Test-FindNumericFilter -Value $ageDays -Op $mtimeFilter.Op -N $mtimeFilter.N)) { continue }
        }
        if ($mminFilter) {
            $ageMins = ($now - $item.LastWriteTime).TotalMinutes
            if (-not (Test-FindNumericFilter -Value $ageMins -Op $mminFilter.Op -N $mminFilter.N)) { continue }
        }
        if ($atimeFilter) {
            $ageDays = ($now - $item.LastAccessTime).TotalDays
            if (-not (Test-FindNumericFilter -Value $ageDays -Op $atimeFilter.Op -N $atimeFilter.N)) { continue }
        }
        if ($ctimeFilter) {
            # Windows 无 Unix ctime，这里用 CreationTime 近似
            $ageDays = ($now - $item.CreationTime).TotalDays
            if (-not (Test-FindNumericFilter -Value $ageDays -Op $ctimeFilter.Op -N $ctimeFilter.N)) { continue }
        }

        # --- 大小（目录跳过 size 过滤，与常见用法一致）---
        if ($sizeFilter) {
            if ($item.PSIsContainer) { continue }
            $len = [long]$item.Length
            $ok = switch ($sizeFilter.Op) {
                '+' { $len -gt $sizeFilter.Bytes }
                '-' { $len -lt $sizeFilter.Bytes }
                default { $len -eq $sizeFilter.Bytes }
            }
            if (-not $ok) { continue }
        }

        # 输出完整路径（接近 Linux find）
        $item.FullName
    }
}
