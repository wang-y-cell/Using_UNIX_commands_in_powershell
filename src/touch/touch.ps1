# touch（-c 不创建，仅更新已存在文件的时间戳）
function touch {
    param(
        [Alias('no-create')]
        [switch]$c,
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$RemainingArguments
    )

    $parsed = Merge-UnixFlagLetters -Seed '' -ExtraSwitches @(
        $(if ($c) { 'c' } else { '' })
    ) -RemainingArguments $RemainingArguments -AllowedPattern '[c]'

    $noCreate = $parsed.Flags.Contains('c')
    if ($parsed.Paths.Count -eq 0) {
        Write-Error 'touch: missing file operand'
        return
    }

    $now = Get-Date
    foreach ($path in $parsed.Paths) {
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
