# cat锛堢畝鍗曞嚱鏁?+ $args锛?
# 鏀寔锛歝at FILE...銆佺閬撹緭鍏ワ紱鐭€夐」 -n锛堝叏閮ㄨ鍙凤級/-b锛堥潪绌鸿琛屽彿锛?
# 渚嬶細cat a.txt
#     cat -n a.txt b.txt
#     Get-Content a.txt | cat -n
Remove-Item -Force alias:cat -ErrorAction SilentlyContinue
function cat {
    begin {
        $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
        $files = @(Get-UnixPathArgs -Arguments $args)

        $numberAll = $flags -contains 'n'
        $numberNonBlank = $flags -contains 'b'
        # -b 浼樺厛浜?-n锛堜笌 GNU cat 涓€鑷达級
        if ($numberNonBlank) { $numberAll = $false }

        $fromPipeline = $MyInvocation.ExpectingInput
        # 鐢ㄥ搱甯岃〃淇濆瓨璁℃暟锛屼究浜?scriptblock 璺ㄤ綔鐢ㄥ煙閫掑
        $state = @{
            LineNo     = 0
            NonBlankNo = 0
        }

        $emit = {
            param([string]$Line)
            if ($numberNonBlank) {
                if ($Line -match '\S') {
                    $state.NonBlankNo++
                    Write-Output ("{0,6}`t{1}" -f $state.NonBlankNo, $Line)
                } else {
                    Write-Output $Line
                }
                return
            }
            if ($numberAll) {
                $state.LineNo++
                Write-Output ("{0,6}`t{1}" -f $state.LineNo, $Line)
                return
            }
            Write-Output $Line
        }
    }

    process {
        if (-not $fromPipeline) { return }
        $line = if ($_ -is [string]) { $_ } else { "$_" }
        & $emit $line
    }

    end {
        if ($fromPipeline) { return }

        if ($files.Count -eq 0) {
            Write-Error 'cat: missing file operand'
            return
        }

        foreach ($file in $files) {
            if ($file -eq '-') {
                Write-Error 'cat: reading stdin via `-` is not supported; pipe input instead'
                continue
            }
            if (-not (Test-Path -LiteralPath $file)) {
                Write-Error "cat: ${file}: No such file or directory"
                continue
            }
            $item = Get-Item -LiteralPath $file -Force
            if ($item.PSIsContainer) {
                Write-Error "cat: ${file}: Is a directory"
                continue
            }

            try {
                foreach ($line in [System.IO.File]::ReadLines($item.FullName)) {
                    & $emit $line
                }
            } catch {
                Write-Error "cat: ${file}: $($_.Exception.Message)"
            }
        }
    }
}
