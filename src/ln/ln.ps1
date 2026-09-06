# ln（简单函数 + $args）
# 支持：ln [-sf] TARGET LINK_NAME
#       ln [-sf] TARGET... DIRECTORY   （多源链到目录）
function ln {
    $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
    $paths = @(Get-UnixPathArgs -Arguments $args)
    $paths = @(Expand-UnixGlob -Path $paths)

    $symbolic = $flags -contains 's'
    $force = $flags -contains 'f'
    $hadError = $false
    Set-UnixExitCode -Code 0

    if ($paths.Count -lt 2) {
        Write-Error 'ln: missing file operand'
        Set-UnixExitCode -Code 1
        return
    }

    $dest = $paths[-1]
    $targets = @($paths[0..($paths.Count - 2)])
    $destIsDir = (Test-Path -LiteralPath $dest) -and (Get-Item -LiteralPath $dest -Force).PSIsContainer

    if ($targets.Count -gt 1 -and -not $destIsDir) {
        Write-Error "ln: target '${dest}' is not a directory"
        Set-UnixExitCode -Code 1
        return
    }

    foreach ($target in $targets) {
        $link = if ($destIsDir) {
            Join-Path $dest (Split-Path -Leaf $target)
        } else {
            $dest
        }

        if (-not $symbolic -and -not (Test-Path -LiteralPath $target)) {
            Write-Error "ln: failed to access '${target}': No such file or directory"
            $hadError = $true
            continue
        }

        if (Test-Path -LiteralPath $link) {
            if (-not $force) {
                Write-Error "ln: failed to create link '${link}': File exists"
                $hadError = $true
                continue
            }
            try {
                Remove-Item -LiteralPath $link -Force -ErrorAction Stop
            } catch {
                Write-Error "ln: cannot replace '${link}': $($_.Exception.Message)"
                $hadError = $true
                continue
            }
        }

        $parent = Split-Path -Parent $link
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            Write-Error "ln: failed to create link '${link}': No such file or directory"
            $hadError = $true
            continue
        }

        try {
            if ($symbolic) {
                New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null
            } else {
                $targetItem = Get-Item -LiteralPath $target -Force
                if ($targetItem.PSIsContainer) {
                    Write-Error "ln: '${target}': hard link not allowed for directories (use -s)"
                    $hadError = $true
                    continue
                }
                New-Item -ItemType HardLink -Path $link -Target $targetItem.FullName -ErrorAction Stop | Out-Null
            }
        } catch {
            Write-Error "ln: failed to create link '${link}': $($_.Exception.Message)"
            $hadError = $true
        }
    }

    if ($hadError) { Set-UnixExitCode -Code 1 }
}
