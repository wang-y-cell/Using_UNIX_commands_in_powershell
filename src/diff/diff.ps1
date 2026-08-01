# diff + $args
# actually diff [-qi] FILE1 FILE2
Remove-Item -Force alias:diff -ErrorAction SilentlyContinue
function diff {
    $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
    $paths = @(Get-UnixPathArgs -Arguments $args)

    $brief = $flags -contains 'q'
    $ignoreCase = $flags -contains 'i'

    if ($paths.Count -lt 2) {
        Write-Error 'diff: missing operand'
        return
    }
    if ($paths.Count -gt 2) {
        Write-Error 'diff: extra operand (only two files supported)'
        return
    }

    $file1 = $paths[0]
    $file2 = $paths[1]

    foreach ($f in @($file1, $file2)) {
        if (-not (Test-Path -LiteralPath $f)) {
            Write-Error "diff: ${f}: No such file or directory"
            return
        }
        if ((Get-Item -LiteralPath $f -Force).PSIsContainer) {
            Write-Error "diff: ${f}: Is a directory (directory diff not supported)"
            return
        }
    }

    try {
        $lines1 = [System.Collections.Generic.List[string]]::new()
        $lines2 = [System.Collections.Generic.List[string]]::new()
        foreach ($line in [System.IO.File]::ReadLines((Get-Item -LiteralPath $file1 -Force).FullName)) {
            $lines1.Add($line)
        }
        foreach ($line in [System.IO.File]::ReadLines((Get-Item -LiteralPath $file2 -Force).FullName)) {
            $lines2.Add($line)
        }
    } catch {
        Write-Error "diff: $($_.Exception.Message)"
        return
    }

    $cmp = if ($ignoreCase) {
        [StringComparer]::OrdinalIgnoreCase
    } else {
        [StringComparer]::Ordinal
    }

    $max = [Math]::Max($lines1.Count, $lines2.Count)
    $differ = $false
    $hunks = [System.Collections.Generic.List[string]]::new()

    $i = 0
    while ($i -lt $max) {
        $a = if ($i -lt $lines1.Count) { $lines1[$i] } else { $null }
        $b = if ($i -lt $lines2.Count) { $lines2[$i] } else { $null }

        $same = if ($null -eq $a -and $null -eq $b) {
            $true
        } elseif ($null -eq $a -or $null -eq $b) {
            $false
        } else {
            $cmp.Equals($a, $b)
        }

        if ($same) {
            $i++
            continue
        }

        $differ = $true
        if ($brief) { break }

        # 鏀堕泦杩炵画宸紓鍧?
        $start = $i + 1
        $old = [System.Collections.Generic.List[string]]::new()
        $new = [System.Collections.Generic.List[string]]::new()
        while ($i -lt $max) {
            $a = if ($i -lt $lines1.Count) { $lines1[$i] } else { $null }
            $b = if ($i -lt $lines2.Count) { $lines2[$i] } else { $null }
            $same = if ($null -eq $a -and $null -eq $b) {
                $true
            } elseif ($null -eq $a -or $null -eq $b) {
                $false
            } else {
                $cmp.Equals($a, $b)
            }
            if ($same) { break }
            if ($null -ne $a) { $old.Add($a) }
            if ($null -ne $b) { $new.Add($b) }
            $i++
        }
        $end = $i

        if ($old.Count -gt 0 -and $new.Count -eq 0) {
            $hunks.Add("${start},${end}d${start}")
            foreach ($line in $old) { $hunks.Add("< $line") }
        } elseif ($old.Count -eq 0 -and $new.Count -gt 0) {
            $hunks.Add("${start}a${start},${end}")
            foreach ($line in $new) { $hunks.Add("> $line") }
        } else {
            $hunks.Add("${start},${end}c${start},${end}")
            foreach ($line in $old) { $hunks.Add("< $line") }
            $hunks.Add('---')
            foreach ($line in $new) { $hunks.Add("> $line") }
        }
    }

    if (-not $differ) { return }

    if ($brief) {
        Write-Output "Files ${file1} and ${file2} differ"
        return
    }

    foreach ($line in $hunks) {
        Write-Output $line
    }
}
