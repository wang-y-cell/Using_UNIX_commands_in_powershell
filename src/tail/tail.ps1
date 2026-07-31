# tail（简单函数 + $args）
# 支持：tail [-n N | -n +N | -N] [FILE...]、管道输入；默认末 10 行
# 例：tail a.txt
#     tail -n 5 a.txt
#     tail -n +3 a.txt
#     Get-Content a.txt | tail -n 3
function tail {
    begin {
        $tailAbort = $false
        $lineCount = 10
        $fromStart = $false # -n +N：从第 N 行起
        $files = [System.Collections.Generic.List[string]]::new()
        $argv = @($args)
        $i = 0

        while ($i -lt $argv.Count) {
            $tok = [string]$argv[$i]
            if ($tok -match '^-n\+(\d+)$') {
                $fromStart = $true
                $lineCount = [int]$Matches[1]
                $i++
                continue
            }
            if ($tok -match '^-n(\d+)$') {
                $fromStart = $false
                $lineCount = [int]$Matches[1]
                $i++
                continue
            }
            if ($tok -eq '-n') {
                if ($i + 1 -ge $argv.Count) {
                    Write-Error 'tail: option requires an argument -- n'
                    $tailAbort = $true
                    return
                }
                $numTok = [string]$argv[$i + 1]
                if ($numTok -match '^\+(\d+)$') {
                    $fromStart = $true
                    $lineCount = [int]$Matches[1]
                } elseif ($numTok -match '^\d+$') {
                    $fromStart = $false
                    $lineCount = [int]$numTok
                } else {
                    Write-Error "tail: invalid number of lines: '${numTok}'"
                    $tailAbort = $true
                    return
                }
                $i += 2
                continue
            }
            if ($tok -match '^-(\d+)$') {
                $fromStart = $false
                $lineCount = [int]$Matches[1]
                $i++
                continue
            }
            if ($tok -match '^-([a-zA-Z]+)$') {
                Write-Error "tail: invalid option -- '$($Matches[1][0])'"
                $tailAbort = $true
                return
            }
            $files.Add($tok)
            $i++
        }

        $fromPipeline = $MyInvocation.ExpectingInput
        $multiFile = $files.Count -gt 1
        $pipeLineNo = 0
        $buffer = [System.Collections.Generic.Queue[string]]::new()
    }

    process {
        if ($tailAbort -or -not $fromPipeline) { return }
        $line = if ($_ -is [string]) { $_ } else { "$_" }
        $pipeLineNo++

        if ($fromStart) {
            if ($pipeLineNo -ge $lineCount) {
                Write-Output $line
            }
            return
        }

        $buffer.Enqueue($line)
        while ($buffer.Count -gt $lineCount) {
            [void]$buffer.Dequeue()
        }
    }

    end {
        if ($tailAbort) { return }

        if ($fromPipeline) {
            if (-not $fromStart) {
                foreach ($line in $buffer) {
                    Write-Output $line
                }
            }
            return
        }

        if ($files.Count -eq 0) {
            Write-Error 'tail: missing file operand'
            return
        }

        $fileIndex = 0
        foreach ($file in $files) {
            if (-not (Test-Path -LiteralPath $file)) {
                Write-Error "tail: cannot open '${file}' for reading: No such file or directory"
                continue
            }
            $item = Get-Item -LiteralPath $file -Force
            if ($item.PSIsContainer) {
                Write-Error "tail: error reading '${file}': Is a directory"
                continue
            }

            if ($multiFile) {
                if ($fileIndex -gt 0) { Write-Output '' }
                Write-Output "==> ${file} <=="
            }
            $fileIndex++

            try {
                if ($fromStart) {
                    $n = 0
                    foreach ($line in [System.IO.File]::ReadLines($item.FullName)) {
                        $n++
                        if ($n -ge $lineCount) {
                            Write-Output $line
                        }
                    }
                } else {
                    $q = [System.Collections.Generic.Queue[string]]::new()
                    foreach ($line in [System.IO.File]::ReadLines($item.FullName)) {
                        $q.Enqueue($line)
                        while ($q.Count -gt $lineCount) {
                            [void]$q.Dequeue()
                        }
                    }
                    foreach ($line in $q) {
                        Write-Output $line
                    }
                }
            } catch {
                Write-Error "tail: '${file}': $($_.Exception.Message)"
            }
        }
    }
}
