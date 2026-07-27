# mv（-f 覆盖, -v 详细）
Remove-Item alias:mv -ErrorAction SilentlyContinue
function mv {
    param(
        [switch]$f,
        [switch]$v,
        [Alias('vf')]
        [switch]$fv,
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$RemainingArguments
    )

    $seed = ''
    if ($f) { $seed += 'f' }
    if ($v) { $seed += 'v' }
    if ($fv) { $seed += 'fv' }

    $parsed = Merge-UnixFlagLetters -Seed $seed -RemainingArguments $RemainingArguments -AllowedPattern '[fFvV]'
    $flagsLower = $parsed.Flags.ToLowerInvariant()
    $force = $flagsLower.Contains('f')
    $verbose = $flagsLower.Contains('v')

    if ($parsed.Paths.Count -lt 2) {
        Write-Error 'mv: missing file operand'
        return
    }

    $dest = $parsed.Paths[-1]
    $sources = $parsed.Paths[0..($parsed.Paths.Length - 2)]

    if ($sources.Count -gt 1) {
        if (-not (Test-Path -LiteralPath $dest) -or -not (Get-Item -LiteralPath $dest).PSIsContainer) {
            Write-Error "mv: target '${dest}' is not a directory"
            return
        }
    }

    foreach ($src in $sources) {
        if (-not (Test-Path -LiteralPath $src)) {
            Write-Error "mv: cannot stat '${src}': No such file or directory"
            continue
        }

        try {
            Move-Item -LiteralPath $src -Destination $dest -Force:$force -ErrorAction Stop
            if ($verbose) {
                Write-Host "'${src}' -> '${dest}'"
            }
        } catch {
            Write-Error "mv: cannot move '${src}' to '${dest}': $($_.Exception.Message)"
        }
    }
}
