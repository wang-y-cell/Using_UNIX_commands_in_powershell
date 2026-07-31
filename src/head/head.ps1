# head（简单函数 + $args）
# 支持：head [-n N | -N] [FILE...]、管道输入；默认前 10 行
# 例：head a.txt
#     head -n 5 a.txt b.txt
#     Get-Content a.txt | head -n 3
function head {
    begin {
        $headAbort = $false
        $lineCount = 10
        $files = [System.Collections.Generic.List[string]]::new()
        $argv = @($args)
        $i = 0
        while ($i -lt $argv.Count) {
            $tok = [string]$argv[$i]
            if ($tok -match '^-n(\d+)$') {
                $lineCount = [int]$Matches[1]
                $i++
                continue
            }
            if ($tok -eq '-n') {
                if ($i + 1 -ge $argv.Count) {
                    Write-Error 'head: option requires an argument -- n'
                    $headAbort = $true
                    return
                }
                $numTok = [string]$argv[$i + 1]
                if ($numTok -notmatch '^\d+$') {
                    Write-Error "head: invalid number of lines: '${numTok}'"
                    $headAbort = $true
                    return
                }
                $lineCount = [int]$numTok
                $i += 2
                continue
            }
            if ($tok -match '^-(\d+)$') {
                $lineCount = [int]$Matches[1]
                $i++
                continue
            }
            if ($tok -match '^-([a-zA-Z]+)$') {
                Write-Error "head: invalid option -- '$($Matches[1][0])'"
                $headAbort = $true
                return
            }
            $files.Add($tok)
            $i++
        }

        $fromPipeline = $MyInvocation.ExpectingInput
        $emitted = 0
        $multiFile = $files.Count -gt 1
    }

    process {
        if ($headAbort -or -not $fromPipeline) { return }
        if ($emitted -ge $lineCount) { return }
        $line = if ($_ -is [string]) { $_ } else { "$_" }
        Write-Output $line
        $emitted++
    }

    end {
        if ($headAbort -or $fromPipeline) { return }

        if ($files.Count -eq 0) {
            Write-Error 'head: missing file operand'
            return
        }

        $fileIndex = 0
        foreach ($file in $files) {
            if (-not (Test-Path -LiteralPath $file)) {
                Write-Error "head: cannot open '${file}' for reading: No such file or directory"
                continue
            }
            $item = Get-Item -LiteralPath $file -Force
            if ($item.PSIsContainer) {
                Write-Error "head: error reading '${file}': Is a directory"
                continue
            }

            if ($multiFile) {
                if ($fileIndex -gt 0) { Write-Output '' }
                Write-Output "==> ${file} <=="
            }
            $fileIndex++

            $n = 0
            try {
                foreach ($line in [System.IO.File]::ReadLines($item.FullName)) {
                    if ($n -ge $lineCount) { break }
                    Write-Output $line
                    $n++
                }
            } catch {
                Write-Error "head: '${file}': $($_.Exception.Message)"
            }
        }
    }
}
