# rm（-r/-R 递归, -f 强制, 支持 -rf/-fr）
Remove-Item alias:rm -ErrorAction SilentlyContinue
function rm {
    param(
        # -r/-R 相同（PS 参数名不区分大小写）
        [switch]$r,
        [switch]$f,
        [Alias('fr')]
        [switch]$rf,
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$RemainingArguments
    )

    $seed = ''
    if ($r) { $seed += 'r' }
    if ($f) { $seed += 'f' }
    if ($rf) { $seed += 'rf' }

    $parsed = Merge-UnixFlagLetters -Seed $seed -RemainingArguments $RemainingArguments -AllowedPattern '[rfRF]'
    $recursive = $parsed.Flags -match '[rR]'
    $force = $parsed.Flags.ToLowerInvariant().Contains('f')

    if ($parsed.Paths.Count -eq 0) {
        Write-Error 'rm: missing operand'
        return
    }

    foreach ($path in $parsed.Paths) {
        if (-not (Test-Path -LiteralPath $path)) {
            if (-not $force) {
                Write-Error "rm: cannot remove '${path}': No such file or directory"
            }
            continue
        }

        $item = Get-Item -LiteralPath $path -Force
        if ($item.PSIsContainer -and -not $recursive) {
            Write-Error "rm: cannot remove '${path}': Is a directory"
            continue
        }

        try {
            $riParams = @{
                LiteralPath = $path
                Recurse     = $recursive
                Force       = $true
                ErrorAction = $(if ($force) { 'SilentlyContinue' } else { 'Stop' })
            }
            Remove-Item @riParams
        } catch {
            if (-not $force) {
                Write-Error "rm: cannot remove '${path}': $($_.Exception.Message)"
            }
        }
    }
}
