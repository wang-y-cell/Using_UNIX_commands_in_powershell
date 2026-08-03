# mv（-f 覆盖, -v 详细）
Remove-Item -Force alias:mv -ErrorAction SilentlyContinue
function mv {
    $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
    $paths = @(Get-UnixPathArgs -Arguments $args)
    $paths = @(Expand-UnixGlob -Path $paths)

    $force = $flags -contains 'f'
    $verbose = $flags -contains 'v'

    if ($paths.Count -lt 2) {
        Write-Error 'mv: missing file operand'
        return
    }

    $dest = $paths[-1]
    $sources = $paths[0..($paths.Length - 2)]

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
