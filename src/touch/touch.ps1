# touch（-c 不创建，仅更新已存在文件的时间戳）
function touch {
    $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
    $paths = @(Get-UnixPathArgs -Arguments $args)

    $noCreate = $flags -contains 'c'
    if ($paths.Count -eq 0) {
        Write-Error 'touch: missing file operand'
        return
    }

    $now = Get-Date
    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path) {
            try {
                $item = Get-Item -LiteralPath $path -Force
                $item.LastAccessTime = $now
                $item.LastWriteTime = $now
            } catch {
                Write-Error "touch: cannot touch '${path}': $($_.Exception.Message)"
            }
            continue
        }

        if ($noCreate) { continue }

        try {
            $parent = Split-Path -Parent $path
            if ($parent -and -not (Test-Path -LiteralPath $parent)) {
                Write-Error "touch: cannot touch '${path}': No such file or directory"
                continue
            }
            New-Item -Path $path -ItemType File -ErrorAction Stop | Out-Null
        } catch {
            Write-Error "touch: cannot touch '${path}': $($_.Exception.Message)"
        }
    }
}
