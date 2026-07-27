# Linux 风格 find（-name/-iname/-type/-mtime/-size ...）
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
    param(
        [Parameter(Position = 0)]
        [string]$Path = '.',

        [string]$name,
        [string]$iname,

        [ValidateSet('f', 'd', 'l', 'F', 'D', 'L')]
        [string]$type,

        # 修改时间：天 / 分钟
        [string]$mtime,
        [string]$mmin,
        # 访问时间：天（Windows: LastAccessTime）
        [string]$atime,
        # 状态变更：天（Windows 近似为 CreationTime）
        [string]$ctime,

        [string]$size
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Error "路径不存在: $Path"
        return
    }

    $sizeFilter = $null
    if ($PSBoundParameters.ContainsKey('size')) {
        $sizeFilter = Convert-FindSizeSpec -Spec ([string]$size)
    }

    $mtimeFilter = if ($PSBoundParameters.ContainsKey('mtime')) { Convert-FindTimeSpec -Spec ([string]$mtime) } else { $null }
    $mminFilter  = if ($PSBoundParameters.ContainsKey('mmin'))  { Convert-FindTimeSpec -Spec ([string]$mmin) }  else { $null }
    $atimeFilter = if ($PSBoundParameters.ContainsKey('atime')) { Convert-FindTimeSpec -Spec ([string]$atime) } else { $null }
    $ctimeFilter = if ($PSBoundParameters.ContainsKey('ctime')) { Convert-FindTimeSpec -Spec ([string]$ctime) } else { $null }

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

    $root = Get-Item -LiteralPath $Path -Force
    $items = @($root) + @(
        Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
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
