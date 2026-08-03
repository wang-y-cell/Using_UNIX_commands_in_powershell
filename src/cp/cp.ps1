# cp（-r/-R 递归, -f 覆盖, -v 详细, 支持 -rf/-rv 等）
Remove-Item -Force alias:cp -ErrorAction SilentlyContinue
function cp {
    $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
    $paths = @(Get-UnixPathArgs -Arguments $args)
    $paths = @(Expand-UnixGlob -Path $paths)

    $recursive = $flags -contains 'r'
    $force = $flags -contains 'f'
    $verbose = $flags -contains 'v'

    if ($paths.Count -lt 2) {
        Write-Error 'cp: missing file operand'
        return
    }

    $dest = $paths[-1]
    $sources = $paths[0..($paths.Length - 2)]

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
