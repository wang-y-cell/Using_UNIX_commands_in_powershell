# mkdir（-p 创建父目录；目录已存在时不报错）
Remove-Item -Force alias:mkdir -ErrorAction SilentlyContinue
Remove-Item function:mkdir -ErrorAction SilentlyContinue
function mkdir {
    $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
    $paths = @(Get-UnixPathArgs -Arguments $args)

    $makeParents = $flags -contains 'p'
    if ($paths.Count -eq 0) {
        Write-Error 'mkdir: missing operand'
        return
    }

    foreach ($dir in $paths) {
        if (Test-Path -LiteralPath $dir) {
            if (-not $makeParents) {
                Write-Error "mkdir: cannot create directory '${dir}': File exists"
            }
            continue
        }

        try {
            if ($makeParents) {
                New-Item -Path $dir -ItemType Directory -Force -ErrorAction Stop | Out-Null
            } else {
                $parent = Split-Path -Parent $dir
                if ($parent -and -not (Test-Path -LiteralPath $parent)) {
                    Write-Error "mkdir: cannot create directory '${dir}': No such file or directory"
                    continue
                }
                New-Item -Path $dir -ItemType Directory -ErrorAction Stop | Out-Null
            }
        } catch {
            Write-Error "mkdir: cannot create directory '${dir}': $($_.Exception.Message)"
        }
    }
}
