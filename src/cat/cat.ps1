# cat（简单函数 + $args）
# 支持：cat FILE...、管道输入；短选项 -n（全部行号）/-b（非空行行号）
# 例：cat a.txt
#     cat -n a.txt b.txt
#     Get-Content a.txt | cat -n
Remove-Item alias:cat -ErrorAction SilentlyContinue
function cat {
    begin {
        $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
        $files = @(Get-UnixPathArgs -Arguments $args)

        $numberAll = $flags -contains 'n'
        $numberNonBlank = $flags -contains 'b'
        # -b 优先于 -n（与 GNU cat 一致）
        if ($numberNonBlank) { $numberAll = $false }

        $fromPipeline = $MyInvocation.ExpectingInput
        # 用哈希表保存计数，便于 scriptblock 跨作用域递增
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
