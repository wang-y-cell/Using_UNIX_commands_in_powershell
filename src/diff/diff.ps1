# diff + $args
# 支持：diff [-qi] FILE1 FILE2；LCS 正常 diff；退出码 0 相同 / 1 不同 / 2 错误
Remove-Item -Force alias:diff -ErrorAction SilentlyContinue
function diff {
    $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
    $paths = @(Get-UnixPathArgs -Arguments $args)
    $paths = @(Expand-UnixGlob -Path $paths)

    $brief = $flags -contains 'q'
    $ignoreCase = $flags -contains 'i'
    Set-UnixExitCode -Code 0

    if ($paths.Count -lt 2) {
        Write-Error 'diff: missing operand'
        Set-UnixExitCode -Code 2
        return
    }
    if ($paths.Count -gt 2) {
        Write-Error 'diff: extra operand (only two files supported)'
        Set-UnixExitCode -Code 2
        return
    }

    $file1 = $paths[0]
    $file2 = $paths[1]

    foreach ($f in @($file1, $file2)) {
        if (-not (Test-Path -LiteralPath $f)) {
            Write-Error "diff: ${f}: No such file or directory"
            Set-UnixExitCode -Code 2
            return
        }
        if ((Get-Item -LiteralPath $f -Force).PSIsContainer) {
            Write-Error "diff: ${f}: Is a directory (directory diff not supported)"
            Set-UnixExitCode -Code 2
            return
        }
    }

    try {
        $lines1 = [string[]]@([System.IO.File]::ReadAllLines((Get-Item -LiteralPath $file1 -Force).FullName))
        $lines2 = [string[]]@([System.IO.File]::ReadAllLines((Get-Item -LiteralPath $file2 -Force).FullName))
    } catch {
        Write-Error "diff: $($_.Exception.Message)"
        Set-UnixExitCode -Code 2
        return
    }

    $cmp = if ($ignoreCase) {
        [StringComparer]::OrdinalIgnoreCase
    } else {
        [StringComparer]::Ordinal
    }

    $ops = Get-UnixDiffOps -A $lines1 -B $lines2 -Comparer $cmp
    $differ = $false
    foreach ($op in $ops) {
        if ($op.Kind -ne 'equal') { $differ = $true; break }
    }

    if (-not $differ) {
        Set-UnixExitCode -Code 0
        return
    }

    Set-UnixExitCode -Code 1
    if ($brief) {
        Write-Output "Files ${file1} and ${file2} differ"
        return
    }

    foreach ($line in (Format-UnixDiffNormal -Ops $ops)) {
        Write-Output $line
    }
}

# LCS 回溯得到 equal/delete/insert 序列
function Get-UnixDiffOps {
    param(
        [string[]]$A,
        [string[]]$B,
        [StringComparer]$Comparer
    )

    $n = $A.Count
    $m = $B.Count
    # 过大时退化为按行对齐，避免 O(n*m) 内存爆炸
    if (($n -gt 4000) -or ($m -gt 4000) -or (($n * $m) -gt 4000000)) {
        return Get-UnixDiffOpsAligned -A $A -B $B -Comparer $Comparer
    }

    $dp = New-Object 'int[,]' ($n + 1), ($m + 1)
    for ($i = $n - 1; $i -ge 0; $i--) {
        for ($j = $m - 1; $j -ge 0; $j--) {
            if ($Comparer.Equals($A[$i], $B[$j])) {
                $dp[$i, $j] = $dp[($i + 1), ($j + 1)] + 1
            } else {
                $dp[$i, $j] = [Math]::Max($dp[($i + 1), $j], $dp[$i, ($j + 1)])
            }
        }
    }

    $ops = [System.Collections.Generic.List[object]]::new()
    $i = 0; $j = 0
    while ($i -lt $n -and $j -lt $m) {
        if ($Comparer.Equals($A[$i], $B[$j])) {
            $ops.Add([pscustomobject]@{ Kind = 'equal'; ALine = $i + 1; BLine = $j + 1; Text = $A[$i] })
            $i++; $j++
        } elseif ($dp[($i + 1), $j] -ge $dp[$i, ($j + 1)]) {
            $ops.Add([pscustomobject]@{ Kind = 'delete'; ALine = $i + 1; BLine = $j + 1; Text = $A[$i] })
            $i++
        } else {
            $ops.Add([pscustomobject]@{ Kind = 'insert'; ALine = $i + 1; BLine = $j + 1; Text = $B[$j] })
            $j++
        }
    }
    while ($i -lt $n) {
        $ops.Add([pscustomobject]@{ Kind = 'delete'; ALine = $i + 1; BLine = $j + 1; Text = $A[$i] })
        $i++
    }
    while ($j -lt $m) {
        $ops.Add([pscustomobject]@{ Kind = 'insert'; ALine = $i + 1; BLine = $j + 1; Text = $B[$j] })
        $j++
    }
    return @($ops)
}

function Get-UnixDiffOpsAligned {
    param([string[]]$A, [string[]]$B, [StringComparer]$Comparer)
    $ops = [System.Collections.Generic.List[object]]::new()
    $max = [Math]::Max($A.Count, $B.Count)
    for ($i = 0; $i -lt $max; $i++) {
        $a = if ($i -lt $A.Count) { $A[$i] } else { $null }
        $b = if ($i -lt $B.Count) { $B[$i] } else { $null }
        if ($null -ne $a -and $null -ne $b -and $Comparer.Equals($a, $b)) {
            $ops.Add([pscustomobject]@{ Kind = 'equal'; ALine = $i + 1; BLine = $i + 1; Text = $a })
        } else {
            if ($null -ne $a) {
                $ops.Add([pscustomobject]@{ Kind = 'delete'; ALine = $i + 1; BLine = [Math]::Min($i + 1, $B.Count); Text = $a })
            }
            if ($null -ne $b) {
                $ops.Add([pscustomobject]@{ Kind = 'insert'; ALine = [Math]::Min($i + 1, $A.Count); BLine = $i + 1; Text = $b })
            }
        }
    }
    return @($ops)
}

function Format-UnixDiffNormal {
    param([object[]]$Ops)

    $out = [System.Collections.Generic.List[string]]::new()
    $i = 0
    while ($i -lt $Ops.Count) {
        if ($Ops[$i].Kind -eq 'equal') { $i++; continue }

        $dels = [System.Collections.Generic.List[object]]::new()
        $adds = [System.Collections.Generic.List[object]]::new()
        while ($i -lt $Ops.Count -and $Ops[$i].Kind -ne 'equal') {
            if ($Ops[$i].Kind -eq 'delete') { $dels.Add($Ops[$i]) }
            elseif ($Ops[$i].Kind -eq 'insert') { $adds.Add($Ops[$i]) }
            $i++
        }

        if ($dels.Count -gt 0 -and $adds.Count -eq 0) {
            $a1 = $dels[0].ALine
            $a2 = $dels[-1].ALine
            $bAt = $dels[0].BLine
            if ($a1 -eq $a2) { $out.Add("${a1}d${bAt}") }
            else { $out.Add("${a1},${a2}d${bAt}") }
            foreach ($d in $dels) { $out.Add("< $($d.Text)") }
        } elseif ($dels.Count -eq 0 -and $adds.Count -gt 0) {
            $b1 = $adds[0].BLine
            $b2 = $adds[-1].BLine
            $aAt = $adds[0].ALine
            if ($b1 -eq $b2) { $out.Add("${aAt}a${b1}") }
            else { $out.Add("${aAt}a${b1},${b2}") }
            foreach ($a in $adds) { $out.Add("> $($a.Text)") }
        } else {
            $a1 = $dels[0].ALine; $a2 = $dels[-1].ALine
            $b1 = $adds[0].BLine; $b2 = $adds[-1].BLine
            $left = if ($a1 -eq $a2) { "$a1" } else { "${a1},${a2}" }
            $right = if ($b1 -eq $b2) { "$b1" } else { "${b1},${b2}" }
            $out.Add("${left}c${right}")
            foreach ($d in $dels) { $out.Add("< $($d.Text)") }
            $out.Add('---')
            foreach ($a in $adds) { $out.Add("> $($a.Text)") }
        }
    }
    return @($out)
}
