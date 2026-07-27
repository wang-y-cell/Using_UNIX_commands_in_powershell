# cp（-r/-R 递归, -f 覆盖, -v 详细, 支持 -rf/-rv 等）
Remove-Item alias:cp -ErrorAction SilentlyContinue
function cp {
    param(
        # -r/-R 相同（PS 参数名不区分大小写）
        [switch]$r,
        [switch]$f,
        [switch]$v,
        [Alias('fr')]
        [switch]$rf,
        [Alias('vr')]
        [switch]$rv,
        [Alias('vf')]
        [switch]$fv,
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$RemainingArguments
    )

    $seed = ''
    if ($r) { $seed += 'r' }
    if ($f) { $seed += 'f' }
    if ($v) { $seed += 'v' }
    if ($rf) { $seed += 'rf' }
    if ($rv) { $seed += 'rv' }
    if ($fv) { $seed += 'fv' }

    $parsed = Merge-UnixFlagLetters -Seed $seed -RemainingArguments $RemainingArguments -AllowedPattern '[rRfFvV]'
    $flagsLower = $parsed.Flags.ToLowerInvariant()
    $recursive = $flagsLower.Contains('r')
    $force = $flagsLower.Contains('f')
    $verbose = $flagsLower.Contains('v')

    if ($parsed.Paths.Count -lt 2) {
        Write-Error 'cp: missing file operand'
        return
    }

    $dest = $parsed.Paths[-1]
    $sources = $parsed.Paths[0..($parsed.Paths.Length - 2)]

    if ($sources.Count -gt 1) {
        if (-not (Test-Path -LiteralPath $dest) -or -not (Get-Item -LiteralPath $dest).PSIsContainer) {
            Write-Error "cp: target '${dest}' is not a directory"
            return
        }
    }

    foreach ($src in $sources) {
        if (-not (Test-Path -LiteralPath $src)) {
            Write-Error "cp: cannot stat '${src}': No such file or directory"
            continue
        }

        $srcItem = Get-Item -LiteralPath $src -Force
        if ($srcItem.PSIsContainer -and -not $recursive) {
            Write-Error "cp: -r not specified; omitting directory '${src}'"
            continue
        }

        try {
            Copy-Item -LiteralPath $src -Destination $dest -Recurse:$recursive -Force:$force -ErrorAction Stop
            if ($verbose) {
                Write-Host "'${src}' -> '${dest}'"
            }
        } catch {
            Write-Error "cp: cannot copy '${src}' to '${dest}': $($_.Exception.Message)"
        }
    }
}
