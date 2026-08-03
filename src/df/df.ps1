# df（简单函数 + $args）
# 支持：df [-h] [PATH...]
# 例：df
#     df -h
#     df -h C:\
function df {
    $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
    $paths = @(Get-UnixPathArgs -Arguments $args)
    $paths = @(Expand-UnixGlob -Path $paths)
    $human = $flags -contains 'h'

    $drives = @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
        Where-Object { $null -ne $_.Used -or $null -ne $_.Free })

    if ($paths.Count -gt 0) {
        $wanted = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($path in $paths) {
            try {
                $full = if (Test-Path -LiteralPath $path) {
                    (Get-Item -LiteralPath $path -Force).FullName
                } else {
                    [System.IO.Path]::GetFullPath($path)
                }
                $root = [System.IO.Path]::GetPathRoot($full)
                if ($root) {
                    $letter = $root.TrimEnd('\', '/').TrimEnd(':')
                    [void]$wanted.Add($letter)
                }
            } catch {
                Write-Error "df: ${path}: $($_.Exception.Message)"
            }
        }
        $drives = @($drives | Where-Object { $wanted.Contains([string]$_.Name) })
    }

    if ($drives.Count -eq 0) {
        Write-Error 'df: no file systems matched'
        return
    }

    $rows = foreach ($d in $drives) {
        $used = [int64]($d.Used)
        $free = [int64]($d.Free)
        $total = $used + $free
        $pct = if ($total -gt 0) { [int][math]::Round(100.0 * $used / $total) } else { 0 }
        [pscustomobject]@{
            Filesystem = "$($d.Name):"
            Size       = $total
            Used       = $used
            Avail      = $free
            UsePct     = $pct
            Mounted    = $d.Root
        }
    }

    if ($human) {
        $fmt = { param($b) Format-FileSize -Bytes $b -HumanReadable }
    } else {
        # 1K blocks（近似 GNU df 默认）
        $fmt = { param($b) [string][int64][math]::Ceiling($b / 1024.0) }
    }

    $sizeH = @($rows | ForEach-Object { & $fmt $_.Size } | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $usedH = @($rows | ForEach-Object { & $fmt $_.Used } | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $availH = @($rows | ForEach-Object { & $fmt $_.Avail } | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    if ($sizeH -lt 4) { $sizeH = 4 }
    if ($usedH -lt 4) { $usedH = 4 }
    if ($availH -lt 5) { $availH = 5 }

    $header = "{0,-12} {1,$sizeH} {2,$usedH} {3,$availH} {4,4} {5}" -f `
        'Filesystem', 'Size', 'Used', 'Avail', 'Use%', 'Mounted on'
    Write-Output $header

    foreach ($r in $rows) {
        $line = "{0,-12} {1,$sizeH} {2,$usedH} {3,$availH} {4,3}% {5}" -f `
            $r.Filesystem,
            (& $fmt $r.Size),
            (& $fmt $r.Used),
            (& $fmt $r.Avail),
            $r.UsePct,
            $r.Mounted
        Write-Output $line
    }
}
