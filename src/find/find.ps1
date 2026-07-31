# Linux 风格 find（-name/-iname/-type/-mtime/-size ...）
# 简单函数：从 $args 解析；支持管道输入路径、管道输出完整路径
# 例：find . -name "*.txt" | grep foo
#     '.\src', '.\docs' | find -type f -name "*.ps1"
Remove-Item -Force alias:find -ErrorAction SilentlyContinue
function find {
    <#
    .SYNOPSIS
        Linux 风格的文件查找（常用子集）
    .EXAMPLE
        find . -name "*.txt"
        find . -iname "*.TXT" -type f
        find . -type d -mtime -1
        find . -type f -size +100M
        find . -name "*.ps1" | grep Color
        '.\src' | find -type f -name "*.ps1"
    #>

    begin {
        $argv = @($args)
        $argPaths = [System.Collections.Generic.List[string]]::new()
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
        $findAbort = $false

        $i = 0
        while ($i -lt $argv.Count) {
            $tok = [string]$argv[$i]
            if ($tok -eq '-name') {
                if ($i + 1 -ge $argv.Count) { Write-Error 'find: missing argument to `-name`'; $findAbort = $true; return }
                $name = [string]$argv[$i + 1]
                $i += 2
                continue
            }
            if ($tok -eq '-iname') {
                if ($i + 1 -ge $argv.Count) { Write-Error 'find: missing argument to `-iname`'; $findAbort = $true; return }
                $iname = [string]$argv[$i + 1]
                $i += 2
                continue
            }
            if ($tok -eq '-type') {
                if ($i + 1 -ge $argv.Count) { Write-Error 'find: missing argument to `-type`'; $findAbort = $true; return }
                $type = [string]$argv[$i + 1]
                $i += 2
                continue
            }
            if ($tok -eq '-mtime') {
                if ($i + 1 -ge $argv.Count) { Write-Error 'find: missing argument to `-mtime`'; $findAbort = $true; return }
                $mtime = [string]$argv[$i + 1]
                $hasMtime = $true
                $i += 2
                continue
            }
            if ($tok -eq '-mmin') {
                if ($i + 1 -ge $argv.Count) { Write-Error 'find: missing argument to `-mmin`'; $findAbort = $true; return }
                $mmin = [string]$argv[$i + 1]
                $hasMmin = $true
                $i += 2
                continue
            }
            if ($tok -eq '-atime') {
                if ($i + 1 -ge $argv.Count) { Write-Error 'find: missing argument to `-atime`'; $findAbort = $true; return }
                $atime = [string]$argv[$i + 1]
                $hasAtime = $true
                $i += 2
                continue
            }
            if ($tok -eq '-ctime') {
                if ($i + 1 -ge $argv.Count) { Write-Error 'find: missing argument to `-ctime`'; $findAbort = $true; return }
                $ctime = [string]$argv[$i + 1]
                $hasCtime = $true
                $i += 2
                continue
            }
            if ($tok -eq '-size') {
                if ($i + 1 -ge $argv.Count) { Write-Error 'find: missing argument to `-size`'; $findAbort = $true; return }
                $size = [string]$argv[$i + 1]
                $hasSize = $true
                $i += 2
                continue
            }
            if ($tok.StartsWith('-')) {
                Write-Error "find: unknown predicate `$tok'"
                $findAbort = $true
                return
            }
            $argPaths.Add($tok)
            $i++
        }

        if ($type -and $type -notin @('f', 'd', 'l', 'F', 'D', 'L')) {
            Write-Error "find: invalid argument `$type' to `-type'"
            $findAbort = $true
            return
        }

        $sizeFilter = $null
        if ($hasSize) {
            try { $sizeFilter = Convert-FindSizeSpec -Spec ([string]$size) }
            catch { Write-Error $_; $findAbort = $true; return }
        }

        $mtimeFilter = $null
        $mminFilter = $null
        $atimeFilter = $null
        $ctimeFilter = $null
        try {
            if ($hasMtime) { $mtimeFilter = Convert-FindTimeSpec -Spec ([string]$mtime) }
            if ($hasMmin)  { $mminFilter  = Convert-FindTimeSpec -Spec ([string]$mmin) }
            if ($hasAtime) { $atimeFilter = Convert-FindTimeSpec -Spec ([string]$atime) }
            if ($hasCtime) { $ctimeFilter = Convert-FindTimeSpec -Spec ([string]$ctime) }
        } catch {
            Write-Error $_
            $findAbort = $true
            return
        }

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
        $fromPipeline = $MyInvocation.ExpectingInput
        $pipePaths = [System.Collections.Generic.List[string]]::new()
    }

    process {
        if ($findAbort -or -not $fromPipeline) { return }

        $p = if ($_ -is [System.IO.FileSystemInfo]) {
            $_.FullName
        } elseif ($_ -is [string]) {
            $_
        } else {
            "$_"
        }
        if (-not [string]::IsNullOrWhiteSpace($p)) {
            $pipePaths.Add($p)
        }
    }

    end {
        if ($findAbort) { return }

        $roots = [System.Collections.Generic.List[string]]::new()
        foreach ($p in $argPaths) { $roots.Add($p) }
        foreach ($p in $pipePaths) { $roots.Add($p) }
        if ($roots.Count -eq 0) { $roots.Add('.') }

        foreach ($path in $roots) {
            if (-not (Test-Path -LiteralPath $path)) {
                Write-Error "find: `${path}': No such file or directory"
                continue
            }

            $root = Get-Item -LiteralPath $path -Force
            $items = @($root) + @(
                Get-ChildItem -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
            )

            foreach ($item in $items) {
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

                if ($namePattern -and -not $namePattern.IsMatch($item.Name)) { continue }
                if ($inamePattern -and -not $inamePattern.IsMatch($item.Name)) { continue }

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
                    $ageDays = ($now - $item.CreationTime).TotalDays
                    if (-not (Test-FindNumericFilter -Value $ageDays -Op $ctimeFilter.Op -N $ctimeFilter.N)) { continue }
                }

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

                Write-Output $item.FullName
            }
        }
    }
}
