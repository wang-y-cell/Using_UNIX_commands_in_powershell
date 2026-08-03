# rm（-r/-R 递归, -f 强制, 支持 -rf/-fr）
Remove-Item -Force alias:rm -ErrorAction SilentlyContinue
function rm {
    $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
    $paths = @(Get-UnixPathArgs -Arguments $args)
    $paths = @(Expand-UnixGlob -Path $paths)

    $recursive = $flags -contains 'r'
    $force = $flags -contains 'f'

    if ($paths.Count -eq 0) {
        Write-Error 'rm: missing operand'
        return
    }

    foreach ($path in $paths) {
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
