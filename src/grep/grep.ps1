# grep（简单函数 + $args）
# 支持：grep PATTERN [FILE...]、管道输入；短选项 -i/-v/-n
# 例：ls | grep txt
#     grep -i error app.log
#     Get-Content app.log | grep -n TODO
function grep {
    begin {
        $grepAbort = $false # 是否终止
        $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })

        $nonFlags = [System.Collections.Generic.List[string]]::new()
        foreach ($arg in @($args)) {
            if ($null -eq $arg) { continue }
            $text = [string]$arg
            if ([string]::IsNullOrWhiteSpace($text)) { continue }
            if ($text -match '^-([a-zA-Z]+)$') { continue }
            $nonFlags.Add($text)
        }

        if ($nonFlags.Count -eq 0) {
            Write-Error 'grep: missing pattern'
            $grepAbort = $true
            return
        }

        $pattern = $nonFlags[0] # 模式
        $files = if ($nonFlags.Count -gt 1) { # 文件
            @($nonFlags.GetRange(1, $nonFlags.Count - 1)) # 获取除模式外的所有文件
        } else {
            @() # 如果没有文件，则返回空数组
        }
        $files = @(Expand-UnixGlob -Path $files)

        $ignoreCase = $flags -contains 'i' # 忽略大小写
        $invert = $flags -contains 'v' # 反转匹配
        $showLineNumber = $flags -contains 'n' # 显示行号
        $fromPipeline = $MyInvocation.ExpectingInput # 是否从管道输入
        $multiFile = $files.Count -gt 1 # 是否多文件
        $pipeLineNo = 0 # 管道行号

        # 优先按正则；若非法且像通配符（如 *.txt），则按通配匹配整行
        $matchLine = $null
        try {
            $regex = [regex]::new(
                $pattern,
                $(if ($ignoreCase) { [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
                  else { [System.Text.RegularExpressions.RegexOptions]::None })
            )
            $matchLine = { param([string]$Line) $regex.IsMatch($Line) }.GetNewClosure()
        } catch {
            if (Test-UnixGlobPattern -Pattern $pattern) {
                $wcOpts = [System.Management.Automation.WildcardOptions]::None
                if ($ignoreCase) {
                    $wcOpts = [System.Management.Automation.WildcardOptions]::IgnoreCase
                }
                $wildcard = [System.Management.Automation.WildcardPattern]::new($pattern, $wcOpts)
                $matchLine = { param([string]$Line) $wildcard.IsMatch($Line) }.GetNewClosure()
            }
            else {
                Write-Error "grep: invalid pattern: $($_.Exception.Message)"
                $grepAbort = $true
                return
            }
        }
    }

    process {
        if ($grepAbort -or -not $fromPipeline) { return } # 如果终止或不是从管道输入，则返回

        $pipeLineNo++ # 管道行号加1
        $line = if ($_ -is [System.IO.FileSystemInfo]) { # 如果输入是文件系统信息
            $_.Name # 则返回文件名
        } elseif ($_ -is [string]) { # 如果输入是字符串
            $_ # 则返回字符串
        } else { # 否则
            "$_" # 则返回字符串
        }

        $matched = & $matchLine $line
        if ($invert) { $matched = -not $matched }
        if (-not $matched) { return }

        if ($showLineNumber) {
            Write-Output "${pipeLineNo}:${line}"
        } else {
            Write-Output $line
        }
    }

    end {
        if ($grepAbort -or $fromPipeline) { return }

        if ($files.Count -eq 0) {
            Write-Error 'grep: no input (provide FILE or pipe data)'
            return
        }

        foreach ($file in $files) {
            if (-not (Test-Path -LiteralPath $file)) {
                Write-Error "grep: ${file}: No such file or directory"
                continue
            }
            $item = Get-Item -LiteralPath $file -Force
            if ($item.PSIsContainer) {
                Write-Error "grep: ${file}: Is a directory"
                continue
            }

            $lineNo = 0
            try {
                foreach ($line in [System.IO.File]::ReadLines($item.FullName)) {
                    $lineNo++
                    $matched = & $matchLine $line
                    if ($invert) { $matched = -not $matched }
                    if (-not $matched) { continue }

                    $out = $line
                    if ($showLineNumber) {
                        $out = "${lineNo}:${out}"
                    }
                    if ($multiFile) {
                        $out = "${file}:${out}"
                    }
                    Write-Output $out
                }
            } catch {
                Write-Error "grep: ${file}: $($_.Exception.Message)"
            }
        }
    }
}
