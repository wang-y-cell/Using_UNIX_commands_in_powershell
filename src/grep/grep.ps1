# grep（简单函数 + $args）
# 支持：grep PATTERN [FILE...]、管道输入；短选项 -i/-v/-n/-F
# 匹配片段以红色高亮（终端直接显示时；继续管道则纯文本）
# 正则非法时回退为字面量（便于搜 F:\mingw 等 Windows 路径）
# 例：ls | grep txt
#     grep -i error app.log
#     echo $env:PATH | grep 'F:\mingw'
#     Get-Content app.log | grep -n TODO
function grep {
    begin {
        $grepAbort = $false # 是否终止
        $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })

        $nonFlags = [System.Collections.Generic.List[string]]::new()
        foreach ($arg in @($args)) {
            if ($null -eq $arg) { continue }
            $text = [string]$arg
            # 允许模式为空白（如 grep ' '）；仅跳过真正的空字符串
            if ($null -eq $text -or $text.Length -eq 0) { continue }
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
        $fixedString = $flags -contains 'f' # 固定字符串（字面量）
        $fromPipeline = $MyInvocation.ExpectingInput # 是否从管道输入
        $multiFile = $files.Count -gt 1 # 是否多文件
        $pipeLineNo = 0 # 管道行号
        # 继续向下游管道时不加颜色，避免污染后续命令
        $colorize = $MyInvocation.PipelinePosition -ge $MyInvocation.PipelineLength

        $matchLine = $null
        $grepRegex = $null
        $grepWildcard = $null
        $grepLiteral = $null
        $literalCmp = if ($ignoreCase) {
            [System.StringComparison]::OrdinalIgnoreCase
        } else {
            [System.StringComparison]::Ordinal
        }

        if ($fixedString) {
            $grepLiteral = $pattern
            $matchLine = {
                param([string]$Line)
                $Line.IndexOf($grepLiteral, $literalCmp) -ge 0
            }.GetNewClosure()
        }
        else {
            # 优先按正则；非法则：通配符 → 通配整行；否则字面量（如 F:\mingw）
            try {
                $grepRegex = [regex]::new(
                    $pattern,
                    $(if ($ignoreCase) { [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
                      else { [System.Text.RegularExpressions.RegexOptions]::None })
                )
                $matchLine = { param([string]$Line) $grepRegex.IsMatch($Line) }.GetNewClosure()
            } catch {
                if (Test-UnixGlobPattern -Pattern $pattern) {
                    $wcOpts = [System.Management.Automation.WildcardOptions]::None
                    if ($ignoreCase) {
                        $wcOpts = [System.Management.Automation.WildcardOptions]::IgnoreCase
                    }
                    $grepWildcard = [System.Management.Automation.WildcardPattern]::new($pattern, $wcOpts)
                    $matchLine = { param([string]$Line) $grepWildcard.IsMatch($Line) }.GetNewClosure()
                }
                else {
                    $grepLiteral = $pattern
                    $matchLine = {
                        param([string]$Line)
                        $Line.IndexOf($grepLiteral, $literalCmp) -ge 0
                    }.GetNewClosure()
                }
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

        $prefix = if ($showLineNumber) { "${pipeLineNo}:" } else { '' }
        Write-GrepLine -Line $line -Prefix $prefix -Colorize:$colorize -Invert:$invert `
            -Regex $grepRegex -Wildcard $grepWildcard -Literal $grepLiteral -IgnoreCase:$ignoreCase
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

                    $prefix = ''
                    if ($multiFile) { $prefix += "${file}:" }
                    if ($showLineNumber) { $prefix += "${lineNo}:" }

                    Write-GrepLine -Line $line -Prefix $prefix -Colorize:$colorize -Invert:$invert `
                        -Regex $grepRegex -Wildcard $grepWildcard -Literal $grepLiteral -IgnoreCase:$ignoreCase
                }
            } catch {
                Write-Error "grep: ${file}: $($_.Exception.Message)"
            }
        }
    }
}

# 输出一行 grep 结果；Colorize 时把匹配片段标红
function Write-GrepLine {
    param(
        [string]$Line,
        [string]$Prefix = '',
        [switch]$Colorize,
        [switch]$Invert,
        [regex]$Regex,
        $Wildcard,
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

    # 通配整行匹配：整行标红
    Write-Host "${Prefix}${red}${Line}${reset}"
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
        Write-Host "${Prefix}${Line}"
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
    Write-Host $sb.ToString()
}
