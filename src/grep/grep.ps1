# grep（简单函数 + $args）
# 支持：grep [OPTIONS] PATTERN [FILE...]、管道 / 无文件时读 stdin
# 选项：-i -v -n -F（字面量）-c -w -l -o -H；-f FILE（从文件读模式）
# 退出码：0 有匹配；1 无匹配；2 错误
# 例：ls | grep txt
#     grep -i error app.log
#     echo $env:PATH | grep -F 'F:\mingw'
function grep {
    begin {
        $grepAbort = $false
        $grepHadMatch = $false
        $grepHadError = $false
        Set-UnixExitCode -Code 0

        $ignoreCase = $false
        $invert = $false
        $showLineNumber = $false
        $fixedString = $false
        $countOnly = $false
        $wordRegexp = $false
        $filesWithMatches = $false
        $onlyMatching = $false
        $withFilename = $false
        $patternFile = $null

        $nonFlags = [System.Collections.Generic.List[string]]::new()
        $argv = @($args)
        $i = 0
        while ($i -lt $argv.Count) {
            $text = if ($null -eq $argv[$i]) { '' } else { [string]$argv[$i] }
            if ($text.Length -eq 0) { $i++; continue }

            if ($text -ceq '-f') {
                if ($i + 1 -ge $argv.Count) {
                    Write-Error 'grep: option requires an argument -- f'
                    $grepAbort = $true; $grepHadError = $true; Set-UnixExitCode -Code 2; return
                }
                $patternFile = [string]$argv[$i + 1]
                $i += 2
                continue
            }
            if ($text -match '^-([a-zA-Z0-9]+)$') {
                foreach ($ch in $Matches[1].ToCharArray()) {
                    switch -CaseSensitive ([string]$ch) {
                        'i' { $ignoreCase = $true }
                        'v' { $invert = $true }
                        'n' { $showLineNumber = $true }
                        'F' { $fixedString = $true }
                        'c' { $countOnly = $true }
                        'w' { $wordRegexp = $true }
                        'l' { $filesWithMatches = $true }
                        'o' { $onlyMatching = $true }
                        'H' { $withFilename = $true }
                        'f' {
                            Write-Error 'grep: option requires an argument -- f'
                            $grepAbort = $true; $grepHadError = $true; Set-UnixExitCode -Code 2; return
                        }
                        default {
                            Write-Error "grep: invalid option -- '$ch'"
                            $grepAbort = $true; $grepHadError = $true; Set-UnixExitCode -Code 2; return
                        }
                    }
                }
                $i++
                continue
            }
            $nonFlags.Add($text)
            $i++
        }

        $patterns = [System.Collections.Generic.List[string]]::new()
        if ($patternFile) {
            if (-not (Test-Path -LiteralPath $patternFile)) {
                Write-Error "grep: ${patternFile}: No such file or directory"
                $grepAbort = $true; $grepHadError = $true; Set-UnixExitCode -Code 2; return
            }
            try {
                foreach ($pline in [System.IO.File]::ReadLines((Get-Item -LiteralPath $patternFile -Force).FullName)) {
                    $patterns.Add($pline)
                }
            } catch {
                Write-Error "grep: ${patternFile}: $($_.Exception.Message)"
                $grepAbort = $true; $grepHadError = $true; Set-UnixExitCode -Code 2; return
            }
        }

        if ($nonFlags.Count -eq 0 -and $patterns.Count -eq 0) {
            Write-Error 'grep: missing pattern'
            $grepAbort = $true; $grepHadError = $true; Set-UnixExitCode -Code 2; return
        }

        $files = @()
        if ($patterns.Count -gt 0) {
            $files = @($nonFlags)
        } else {
            $patterns.Add($nonFlags[0])
            if ($nonFlags.Count -gt 1) {
                $files = @($nonFlags.GetRange(1, $nonFlags.Count - 1))
            }
        }
        $files = @(Expand-UnixGlob -Path $files)

        $fromPipeline = $MyInvocation.ExpectingInput
        $multiFile = ($files.Count -gt 1) -or $withFilename
        $pipeLineNo = 0
        $pipeMatchCount = 0
        $colorize = ($MyInvocation.PipelinePosition -ge $MyInvocation.PipelineLength) -and
            (-not $countOnly) -and (-not $filesWithMatches)

        $literalCmp = if ($ignoreCase) {
            [System.StringComparison]::OrdinalIgnoreCase
        } else {
            [System.StringComparison]::Ordinal
        }

        $grepRegex = $null
        $grepLiteral = $null
        $matchMode = 'regex' # regex | literal

        if ($fixedString -or ($patterns.Count -eq 1 -and $patterns[0].Length -eq 0)) {
            $matchMode = 'literal'
            $grepLiteral = $patterns[0]
            if ($patterns.Count -gt 1) {
                # 多字面量：合并为正则转义
                $matchMode = 'regex'
                $escaped = @($patterns | ForEach-Object { [regex]::Escape($_) })
                $body = ($escaped -join '|')
                if ($wordRegexp) { $body = "\b(?:$body)\b" }
                $grepRegex = [regex]::new(
                    $body,
                    $(if ($ignoreCase) { [Text.RegularExpressions.RegexOptions]::IgnoreCase }
                      else { [Text.RegularExpressions.RegexOptions]::None })
                )
            } elseif ($wordRegexp) {
                $matchMode = 'regex'
                $grepRegex = [regex]::new(
                    ('\b' + [regex]::Escape($grepLiteral) + '\b'),
                    $(if ($ignoreCase) { [Text.RegularExpressions.RegexOptions]::IgnoreCase }
                      else { [Text.RegularExpressions.RegexOptions]::None })
                )
                $grepLiteral = $null
            }
        } else {
            try {
                $body = if ($patterns.Count -eq 1) { $patterns[0] } else { '(?:' + ($patterns -join ')|(?:') + ')' }
                if ($wordRegexp) { $body = "\b(?:$body)\b" }
                $grepRegex = [regex]::new(
                    $body,
                    $(if ($ignoreCase) { [Text.RegularExpressions.RegexOptions]::IgnoreCase }
                      else { [Text.RegularExpressions.RegexOptions]::None })
                )
            } catch {
                Write-Error "grep: invalid pattern: $($_.Exception.Message)"
                $grepAbort = $true; $grepHadError = $true; Set-UnixExitCode -Code 2; return
            }
        }

        $testMatch = {
            param([string]$Line)
            if ($matchMode -eq 'literal') {
                return $Line.IndexOf($grepLiteral, $literalCmp) -ge 0
            }
            return $grepRegex.IsMatch($Line)
        }.GetNewClosure()
    }

    process {
        if ($grepAbort -or -not $fromPipeline) { return }

        $pipeLineNo++
        $line = if ($_ -is [System.IO.FileSystemInfo]) {
            $_.Name
        } elseif ($_ -is [string]) {
            $_
        } else {
            "$_"
        }

        $matched = & $testMatch $line
        if ($invert) { $matched = -not $matched }
        if (-not $matched) { return }

        $grepHadMatch = $true
        if ($countOnly) { $pipeMatchCount++; return }
        if ($filesWithMatches) { return }

        if ($onlyMatching -and -not $invert) {
            Write-GrepOnlyMatching -Line $line -LineNo $pipeLineNo -FilePrefix '' `
                -ShowLineNumber:$showLineNumber -Colorize:$colorize `
                -Regex $grepRegex -Literal $grepLiteral -IgnoreCase:$ignoreCase
            return
        }

        $prefix = if ($showLineNumber) { "${pipeLineNo}:" } else { '' }
        Write-GrepLine -Line $line -Prefix $prefix -Colorize:$colorize -Invert:$invert `
            -Regex $grepRegex -Literal $grepLiteral -IgnoreCase:$ignoreCase
    }

    end {
        if ($grepAbort) { return }

        if ($fromPipeline) {
            if ($countOnly) { Write-Output $pipeMatchCount }
            if ($grepHadError) { Set-UnixExitCode -Code 2 }
            elseif ($grepHadMatch) { Set-UnixExitCode -Code 0 }
            else { Set-UnixExitCode -Code 1 }
            return
        }

        if ($files.Count -eq 0) {
            $stdinLines = @(Read-UnixStdinLines)
            $n = 0
            $cnt = 0
            foreach ($line in $stdinLines) {
                $n++
                $matched = & $testMatch $line
                if ($invert) { $matched = -not $matched }
                if (-not $matched) { continue }
                $grepHadMatch = $true
                if ($countOnly) { $cnt++; continue }
                if ($filesWithMatches) { Write-Output '(standard input)'; break }
                if ($onlyMatching -and -not $invert) {
                    Write-GrepOnlyMatching -Line $line -LineNo $n -FilePrefix '' `
                        -ShowLineNumber:$showLineNumber -Colorize:$colorize `
                        -Regex $grepRegex -Literal $grepLiteral -IgnoreCase:$ignoreCase
                    continue
                }
                $prefix = if ($showLineNumber) { "${n}:" } else { '' }
                Write-GrepLine -Line $line -Prefix $prefix -Colorize:$colorize -Invert:$invert `
                    -Regex $grepRegex -Literal $grepLiteral -IgnoreCase:$ignoreCase
            }
            if ($countOnly) { Write-Output $cnt }
            if ($grepHadError) { Set-UnixExitCode -Code 2 }
            elseif ($grepHadMatch) { Set-UnixExitCode -Code 0 }
            else { Set-UnixExitCode -Code 1 }
            return
        }

        foreach ($file in $files) {
            if (-not (Test-Path -LiteralPath $file)) {
                Write-Error "grep: ${file}: No such file or directory"
                $grepHadError = $true
                continue
            }
            $item = Get-Item -LiteralPath $file -Force
            if ($item.PSIsContainer) {
                Write-Error "grep: ${file}: Is a directory"
                $grepHadError = $true
                continue
            }

            $lineNo = 0
            $fileCount = 0
            $fileMatched = $false
            try {
                foreach ($line in [System.IO.File]::ReadLines($item.FullName)) {
                    $lineNo++
                    $matched = & $testMatch $line
                    if ($invert) { $matched = -not $matched }
                    if (-not $matched) { continue }

                    $grepHadMatch = $true
                    $fileMatched = $true
                    if ($countOnly) { $fileCount++; continue }
                    if ($filesWithMatches) { Write-Output $file; break }

                    $filePrefix = if ($multiFile) { "${file}:" } else { '' }
                    if ($onlyMatching -and -not $invert) {
                        Write-GrepOnlyMatching -Line $line -LineNo $lineNo -FilePrefix $filePrefix `
                            -ShowLineNumber:$showLineNumber -Colorize:$colorize `
                            -Regex $grepRegex -Literal $grepLiteral -IgnoreCase:$ignoreCase
                        continue
                    }

                    $prefix = $filePrefix
                    if ($showLineNumber) { $prefix += "${lineNo}:" }
                    Write-GrepLine -Line $line -Prefix $prefix -Colorize:$colorize -Invert:$invert `
                        -Regex $grepRegex -Literal $grepLiteral -IgnoreCase:$ignoreCase
                }
            } catch {
                Write-Error "grep: ${file}: $($_.Exception.Message)"
                $grepHadError = $true
            }

            if ($countOnly) {
                if ($multiFile) { Write-Output "${file}:${fileCount}" }
                else { Write-Output $fileCount }
            }
        }

        if ($grepHadError) { Set-UnixExitCode -Code 2 }
        elseif ($grepHadMatch) { Set-UnixExitCode -Code 0 }
        else { Set-UnixExitCode -Code 1 }
    }
}

function Write-GrepOnlyMatching {
    param(
        [string]$Line,
        [int]$LineNo,
        [string]$FilePrefix,
        [switch]$ShowLineNumber,
        [switch]$Colorize,
        [regex]$Regex,
        [string]$Literal,
        [switch]$IgnoreCase
    )

    $prefix = $FilePrefix
    if ($ShowLineNumber) { $prefix += "${LineNo}:" }

    $parts = [System.Collections.Generic.List[string]]::new()
    if ($null -ne $Regex) {
        foreach ($m in $Regex.Matches($Line)) {
            if ($m.Length -gt 0) { $parts.Add($m.Value) }
        }
    } elseif (-not [string]::IsNullOrEmpty($Literal)) {
        $cmp = if ($IgnoreCase) {
            [System.StringComparison]::OrdinalIgnoreCase
        } else {
            [System.StringComparison]::Ordinal
        }
        $start = 0
        while (($idx = $Line.IndexOf($Literal, $start, $cmp)) -ge 0) {
            $parts.Add($Line.Substring($idx, $Literal.Length))
            $start = $idx + $Literal.Length
        }
    }

    foreach ($p in $parts) {
        if ($Colorize) {
            $red = "$([char]27)[38;2;$($RED[0]);$($RED[1]);$($RED[2])m"
            $reset = "$([char]27)[0m"
            Write-Output "${prefix}${red}${p}${reset}"
        } else {
            Write-Output "${prefix}${p}"
        }
    }
}

function Write-GrepLine {
    param(
        [string]$Line,
        [string]$Prefix = '',
        [switch]$Colorize,
        [switch]$Invert,
        [regex]$Regex,
        [string]$Literal,
        [switch]$IgnoreCase
    )

    if (-not $Colorize -or $Invert) {
        Write-Output "${Prefix}${Line}"
        return
    }

    $red = "$([char]27)[38;2;$($RED[0]);$($RED[1]);$($RED[2])m"
    $reset = "$([char]27)[0m"

    if ($null -ne $Regex) {
        Write-GrepColoredSpans -Line $Line -Prefix $Prefix -Red $red -Reset $reset -Spans @(
            foreach ($m in $Regex.Matches($Line)) {
                if ($m.Length -gt 0) {
                    [pscustomobject]@{ Index = $m.Index; Length = $m.Length }
                }
            }
        )
        return
    }

    if (-not [string]::IsNullOrEmpty($Literal)) {
        $cmp = if ($IgnoreCase) {
            [System.StringComparison]::OrdinalIgnoreCase
        } else {
            [System.StringComparison]::Ordinal
        }
        $spans = [System.Collections.Generic.List[object]]::new()
        $start = 0
        $litLen = $Literal.Length
        if ($litLen -gt 0) {
            while ($true) {
                $idx = $Line.IndexOf($Literal, $start, $cmp)
                if ($idx -lt 0) { break }
                $spans.Add([pscustomobject]@{ Index = $idx; Length = $litLen })
                $start = $idx + $litLen
            }
        }
        Write-GrepColoredSpans -Line $Line -Prefix $Prefix -Red $red -Reset $reset -Spans @($spans)
        return
    }

    Write-Output "${Prefix}${Line}"
}

function Write-GrepColoredSpans {
    param(
        [string]$Line,
        [string]$Prefix,
        [string]$Red,
        [string]$Reset,
        [object[]]$Spans
    )

    if (-not $Spans -or $Spans.Count -eq 0) {
        Write-Output "${Prefix}${Line}"
        return
    }

    $sb = [System.Text.StringBuilder]::new()
    if ($Prefix) { [void]$sb.Append($Prefix) }
    $last = 0
    foreach ($sp in $Spans) {
        if ($sp.Index -gt $last) {
            [void]$sb.Append($Line.Substring($last, $sp.Index - $last))
        }
        [void]$sb.Append($Red)
        [void]$sb.Append($Line.Substring($sp.Index, $sp.Length))
        [void]$sb.Append($Reset)
        $last = $sp.Index + $sp.Length
    }
    if ($last -lt $Line.Length) {
        [void]$sb.Append($Line.Substring($last))
    }
    Write-Output $sb.ToString()
}
