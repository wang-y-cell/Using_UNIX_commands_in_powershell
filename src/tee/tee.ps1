# tee锛堢畝鍗曞嚱鏁?+ $args锛?
# 鏀寔锛?.. | tee [-a] FILE... 锛涘皢绠￠亾鍐呭鍚屾椂鍐欏埌鏂囦欢涓庢垚鍔熸祦
# 渚嬶細Get-Content a.txt | tee out.txt
#     ls | tee -a log.txt
Remove-Item -Force alias:tee -ErrorAction SilentlyContinue
function tee {
    begin {
        $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
        $files = @(Get-UnixPathArgs -Arguments $args)
        $append = $flags -contains 'a'
        $teeAbort = $false
        $writers = [System.Collections.Generic.List[System.IO.StreamWriter]]::new()

        if (-not $MyInvocation.ExpectingInput) {
            Write-Error 'tee: no input (pipe data into tee)'
            $teeAbort = $true
            return
        }
        if ($files.Count -eq 0) {
            Write-Error 'tee: missing file operand'
            $teeAbort = $true
            return
        }

        $utf8 = [System.Text.UTF8Encoding]::new($false)
        foreach ($file in $files) {
            try {
                $dir = Split-Path -Parent $file
                if ($dir -and -not (Test-Path -LiteralPath $dir)) {
                    Write-Error "tee: ${file}: No such file or directory"
                    $teeAbort = $true
                    break
                }
                $writer = [System.IO.StreamWriter]::new($file, $append, $utf8)
                $writers.Add($writer)
            } catch {
                Write-Error "tee: ${file}: $($_.Exception.Message)"
                $teeAbort = $true
                break
            }
        }

        if ($teeAbort) {
            foreach ($w in $writers) { $w.Dispose() }
            $writers.Clear()
        }
    }

    process {
        if ($teeAbort) { return }
        $line = if ($_ -is [string]) { $_ } else { "$_" }
        foreach ($w in $writers) {
            $w.WriteLine($line)
        }
        Write-Output $line
    }

    end {
        foreach ($w in $writers) {
            try { $w.Flush(); $w.Dispose() } catch { }
        }
    }
}
