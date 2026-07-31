# wc（简单函数 + $args）
# 支持：wc [-lwc] [FILE...]、管道输入；默认输出 行/词/字节
# 例：wc a.txt
#     wc -l a.txt b.txt
#     Get-Content a.txt | wc -l
function wc {
    begin {
        $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
        $files = @(Get-UnixPathArgs -Arguments $args)

        $showLines = $flags -contains 'l'
        $showWords = $flags -contains 'w'
        $showBytes = $flags -contains 'c'
        if (-not ($showLines -or $showWords -or $showBytes)) {
            $showLines = $true
            $showWords = $true
            $showBytes = $true
        }

        $fromPipeline = $MyInvocation.ExpectingInput
        $state = @{
            Lines = 0
            Words = 0
            Bytes = 0
        }

        $countLine = {
            param([string]$Line, [hashtable]$S)
            $S.Lines++
            if ($Line.Length -gt 0) {
                $S.Words += @($Line.Split([char[]]@(' ', "`t", "`r", "`n"), [System.StringSplitOptions]::RemoveEmptyEntries)).Count
            }
            # 按 UTF-8 字节计（接近 GNU wc -c 在 UTF-8 环境下的行为）
            $S.Bytes += [System.Text.Encoding]::UTF8.GetByteCount($Line) + [System.Text.Encoding]::UTF8.GetByteCount([Environment]::NewLine)
        }

        $formatCounts = {
            param([int]$Lines, [int]$Words, [int]$Bytes, [string]$Label)
            $parts = [System.Collections.Generic.List[string]]::new()
            if ($showLines) { $parts.Add(('{0,8}' -f $Lines)) }
            if ($showWords) { $parts.Add(('{0,8}' -f $Words)) }
            if ($showBytes) { $parts.Add(('{0,8}' -f $Bytes)) }
            $text = ($parts -join ' ')
            if ($Label) {
                Write-Output "$text $Label"
            } else {
                Write-Output $text
            }
        }
    }

    process {
        if (-not $fromPipeline) { return }
        $line = if ($_ -is [string]) { $_ } else { "$_" }
        & $countLine $line $state
    }

    end {
        if ($fromPipeline) {
            & $formatCounts $state.Lines $state.Words $state.Bytes ''
            return
        }

        if ($files.Count -eq 0) {
            Write-Error 'wc: missing file operand'
            return
        }

        $totalLines = 0
        $totalWords = 0
        $totalBytes = 0
        $okCount = 0

        foreach ($file in $files) {
            if (-not (Test-Path -LiteralPath $file)) {
                Write-Error "wc: ${file}: No such file or directory"
                continue
            }
            $item = Get-Item -LiteralPath $file -Force
            if ($item.PSIsContainer) {
                Write-Error "wc: ${file}: Is a directory"
                continue
            }

            $s = @{ Lines = 0; Words = 0; Bytes = 0 }
            try {
                # 字节数用文件实际大小（更接近 GNU wc -c）
                $s.Bytes = [int64]$item.Length
                foreach ($line in [System.IO.File]::ReadLines($item.FullName)) {
                    $s.Lines++
                    if ($line.Length -gt 0) {
                        $s.Words += @($line.Split([char[]]@(' ', "`t", "`r", "`n"), [System.StringSplitOptions]::RemoveEmptyEntries)).Count
                    }
                }
            } catch {
                Write-Error "wc: ${file}: $($_.Exception.Message)"
                continue
            }

            & $formatCounts $s.Lines $s.Words $s.Bytes $file
            $totalLines += $s.Lines
            $totalWords += $s.Words
            $totalBytes += $s.Bytes
            $okCount++
        }

        if ($okCount -gt 1) {
            & $formatCounts $totalLines $totalWords $totalBytes 'total'
        }
    }
}
