# 智能 ls（横向 / 长列表，支持组合参数）
# 选项：-a -A -l -h -1 -d -t -r（-h 仅在 -l 下生效，不单独开长列表）
function ls-horizontal {
    $flags = @(Get-UnixShortFlagChars -Arguments $args)
    $flagLower = @($flags | ForEach-Object { $_.ToLowerInvariant() })
    $pathArgs = @(Get-UnixPathArgs -Arguments $args)
    $hadPathArgs = $pathArgs.Count -gt 0
    $pathArgs = @(Expand-UnixGlob -Path $pathArgs)

    $hadError = $false
    Set-UnixExitCode -Code 0

    # 用户传了路径/通配，但展开后为空 → 不回退到当前目录
    if ($hadPathArgs -and $pathArgs.Count -eq 0) {
        return
    }

    if ($pathArgs.Count -gt 0) {
        $existing = [System.Collections.Generic.List[string]]::new()
        foreach ($p in $pathArgs) {
            if (Test-Path -LiteralPath $p) {
                $existing.Add($p)
            }
            else {
                Write-Error "ls: cannot access '${p}': No such file or directory"
                $hadError = $true
            }
        }
        $pathArgs = @($existing)
        if ($hadPathArgs -and $pathArgs.Count -eq 0) {
            if ($hadError) { Set-UnixExitCode -Code 2 }
            return
        }
    }

    $showAll = $flags -contains 'a'          # -a：显示隐藏（含 . / .. 语义）
    $almostAll = $flags -contains 'A'        # -A：显示隐藏，但不含 . / ..
    if ($showAll) { $almostAll = $false }   # -a 优先于 -A

    $longFormat = $flagLower -contains 'l'
    $humanReadable = $flagLower -contains 'h'
    $onePerLine = $flags -contains '1'
    $directoryOnly = $flagLower -contains 'd'
    $sortByTime = $flagLower -contains 't'
    $sortReverse = $flagLower -contains 'r'
    # -h 不再偷偷开启 -l（对齐 GNU：无 -l 时 -h 无效果）

    $pipingOut = $MyInvocation.PipelinePosition -lt $MyInvocation.PipelineLength
    if ($pipingOut -and -not $longFormat) { $onePerLine = $true }

    $gciForce = $showAll -or $almostAll -or ($flags -contains 'A')

    $filterItems = {
        param([object[]]$Items)
        $list = @($Items)
        if ($showAll) {
            # 保留全部；Windows 的 Get-ChildItem 通常不含 . / ..
        } elseif ($almostAll -or ($flags -contains 'A')) {
            $list = @($list | Where-Object { $_.Name -ne '.' -and $_.Name -ne '..' })
        } else {
            $list = @($list | Where-Object { $_.Name -notlike '.*' })
        }

        if ($sortByTime) {
            $list = @($list | Sort-Object LastWriteTime -Descending)
        } else {
            $list = @($list | Sort-Object Name)
        }
        if ($sortReverse) {
            [Array]::Reverse($list)
        }
        return $list
    }.GetNewClosure()

    # -d：把目录操作数本身当项列出，不进入
    if ($directoryOnly) {
        $items = [System.Collections.Generic.List[object]]::new()
        if ($pathArgs.Count -eq 0) {
            $items.Add((Get-Item -LiteralPath (Get-Location).Path -Force))
        } else {
            foreach ($p in $pathArgs) {
                $it = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
                if ($it) { $items.Add($it) }
            }
        }
        $items = & $filterItems @($items)
        Write-LsItems -Items $items -LongFormat:$longFormat -HumanReadable:$humanReadable `
            -PipingOut:$pipingOut -OnePerLine:$onePerLine
        if ($hadError) { Set-UnixExitCode -Code 2 }
        return
    }

    if ($pathArgs.Count -eq 0) {
        $gciParams = @{ ErrorAction = 'SilentlyContinue' }
        if ($gciForce) { $gciParams.Force = $true }
        $items = & $filterItems @(Get-ChildItem @gciParams)
        Write-LsItems -Items $items -LongFormat:$longFormat -HumanReadable:$humanReadable `
            -PipingOut:$pipingOut -OnePerLine:$onePerLine
        if ($hadError) { Set-UnixExitCode -Code 2 }
        return
    }

    $fileItems = [System.Collections.Generic.List[object]]::new()
    $dirLabels = [System.Collections.Generic.List[string]]::new()
    foreach ($p in $pathArgs) {
        $item = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
        if (-not $item) { continue }
        if ($item.PSIsContainer) { $dirLabels.Add($p) }
        else { $fileItems.Add($item) }
    }

    $fileItems = & $filterItems @($fileItems)
    $dirLabels = @($dirLabels | Sort-Object)
    if ($sortReverse) { [Array]::Reverse($dirLabels) }

    $showHeaders = ($fileItems.Count + $dirLabels.Count) -gt 1
    $sectionCount = 0

    if ($fileItems.Count -gt 0) {
        Write-LsItems -Items $fileItems -LongFormat:$longFormat -HumanReadable:$humanReadable `
            -PipingOut:$pipingOut -OnePerLine:$onePerLine
        $sectionCount++
    }

    foreach ($dir in $dirLabels) {
        if ($showHeaders) {
            if ($sectionCount -gt 0) {
                if ($pipingOut) { Write-Output '' } else { Write-Host '' }
            }
            if ($pipingOut) { Write-Output "${dir}:" }
            else { Write-Host "${dir}:" }
        }

        $dirParams = @{
            ErrorAction = 'SilentlyContinue'
            LiteralPath = $dir
        }
        if ($gciForce) { $dirParams.Force = $true }

        $items = & $filterItems @(Get-ChildItem @dirParams)
        Write-LsItems -Items $items -LongFormat:$longFormat -HumanReadable:$humanReadable `
            -PipingOut:$pipingOut -OnePerLine:$onePerLine
        $sectionCount++
    }

    if ($hadError) { Set-UnixExitCode -Code 2 }
}

# 输出一组 ls 项：管道名 / 长列表 / 横向多列 / -1 单列
function Write-LsItems {
    param(
        [object[]]$Items,
        [switch]$LongFormat,
        [switch]$HumanReadable,
        [switch]$PipingOut,
        [switch]$OnePerLine
    )

    if (-not $Items -or $Items.Count -eq 0) { return }

    if ($PipingOut -and -not $LongFormat) {
        foreach ($item in $Items) {
            $item.Name
        }
        return
    }

    if ($LongFormat) {
        $sizeTexts = @(foreach ($item in $Items) {
            $sizeBytes = if ($item.PSIsContainer) { $null } else { $item.Length }
            Format-FileSize -Bytes $sizeBytes -HumanReadable:$HumanReadable
        })
        $sizeWidth = 1
        foreach ($st in $sizeTexts) {
            if ($st.Length -gt $sizeWidth) { $sizeWidth = $st.Length }
        }

        $i = 0
        foreach ($item in $Items) {
            $modeText = if ($null -ne $item.Mode -and $item.Mode -ne '') { $item.Mode } else { '------' }
            $timeText = $item.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
            $sizeText = $sizeTexts[$i].PadLeft($sizeWidth)
            $i++
            $lineText = "$modeText  $timeText  $sizeText  $($item.Name)"

            if ($PipingOut) {
                Write-Output $lineText
                continue
            }

            $rgb = Get-ItemColor $item
            Write-RGB -Text "$modeText  " -R $BLUE[0] -G $BLUE[1] -B $BLUE[2] -NoNewline
            Write-RGB -Text "$timeText  " -R $GRAY[0] -G $GRAY[1] -B $GRAY[2] -NoNewline
            Write-RGB -Text "$sizeText  " -R $DARK_GRAY[0] -G $DARK_GRAY[1] -B $DARK_GRAY[2] -NoNewline
            Write-RGB -Text $item.Name -R $rgb[0] -G $rgb[1] -B $rgb[2]
        }
        return
    }

    if ($OnePerLine) {
        foreach ($item in $Items) {
            $rgb = Get-ItemColor $item
            Write-RGB -Text $item.Name -R $rgb[0] -G $rgb[1] -B $rgb[2]
        }
        return
    }

    $width = $Host.UI.RawUI.WindowSize.Width
    Format-LsColumnMajor -Items $Items -Width $width
}

# 横向多列：全局最长文件名 +2 作为统一列宽（旧策略，暂不调用）
function Format-LsHorizontalUniform {
    param(
        [object[]]$Items,
        [int]$Width
    )

    $maxVisualLen = 0
    foreach ($item in $Items) {
        $len = Get-VisualWidth $item.Name
        if ($len -gt $maxVisualLen) { $maxVisualLen = $len }
    }

    if ($maxVisualLen -gt ($Width / 2)) {
        foreach ($item in $Items) {
            $rgb = Get-ItemColor $item
            Write-RGB -Text $item.Name -R $rgb[0] -G $rgb[1] -B $rgb[2]
        }
        return
    }

    $minColumnWidth = $maxVisualLen + 2
    if ($minColumnWidth -lt 15) { $minColumnWidth = 15 }

    $maxColumns = [Math]::Max(1, [Math]::Floor($Width / $minColumnWidth))
    $count = 0

    foreach ($item in $Items) {
        $rgb = Get-ItemColor $item
        $currentVisualWidth = Get-VisualWidth $item.Name
        $paddingCount = $minColumnWidth - $currentVisualWidth
        $padding = ' ' * $paddingCount

        Write-RGB -Text $item.Name -R $rgb[0] -G $rgb[1] -B $rgb[2] -NoNewline
        Write-Host $padding -NoNewline

        $count++
        if ($count % $maxColumns -eq 0) { Write-Host '' }
    }

    if ($count % $maxColumns -ne 0) { Write-Host '' }
}

# 横向多列：按列取最长文件名 +2，各列宽度可不同，尽量减少行数
function Format-LsHorizontalPerColumn {
    param(
        [object[]]$Items,
        [int]$Width
    )

    $count = $Items.Count
    if ($count -eq 0) { return }

    $visualWidths = [int[]]::new($count)
    for ($i = 0; $i -lt $count; $i++) {
        $visualWidths[$i] = Get-VisualWidth $Items[$i].Name
    }

    # 从尽可能多的列数往下试，找到第一个总宽不超过终端的布局
    $bestCols = 1
    $bestColMax = [int[]]::new(1)
    $bestColMax[0] = ($visualWidths | Measure-Object -Maximum).Maximum

    $maxTryCols = [Math]::Min($count, [Math]::Max(1, $Width))
    for ($cols = $maxTryCols; $cols -ge 1; $cols--) {
        $colMax = [int[]]::new($cols)
        for ($i = 0; $i -lt $count; $i++) {
            $col = $i % $cols
            if ($visualWidths[$i] -gt $colMax[$col]) {
                $colMax[$col] = $visualWidths[$i]
            }
        }

        $total = 0
        for ($c = 0; $c -lt $cols; $c++) {
            # 非末列：最长名 +2 作为列宽；末列无需尾部间距
            if ($c -lt $cols - 1) {
                $total += $colMax[$c] + 2
            }
            else {
                $total += $colMax[$c]
            }
        }

        if ($total -le $Width) {
            $bestCols = $cols
            $bestColMax = $colMax
            break
        }
    }

    for ($i = 0; $i -lt $count; $i++) {
        $col = $i % $bestCols
        $rgb = Get-ItemColor $Items[$i]
        Write-RGB -Text $Items[$i].Name -R $rgb[0] -G $rgb[1] -B $rgb[2] -NoNewline

        if ($col -lt $bestCols - 1) {
            $paddingCount = ($bestColMax[$col] + 2) - $visualWidths[$i]
            if ($paddingCount -gt 0) {
                Write-Host (' ' * $paddingCount) -NoNewline
            }
        }
        else {
            Write-Host ''
        }
    }

    if (($count % $bestCols) -ne 0) { Write-Host '' }
}

# Linux 风格多列：先下后右（column-major），按列最长文件名 +2 定宽
function Format-LsColumnMajor {
    param(
        [object[]]$Items, #文件列表，每个对象是一个文件对象
        [int]$Width #终端宽度
    )

    $count = $Items.Count #获取项数
    if ($count -eq 0) { return } #如果项数为0，则返回

    $visualWidths = [int[]]::new($count) #创建一个长度为count的整数数组,这里存放每一项的视觉宽度
    for ($i = 0; $i -lt $count; $i++) { #遍历每一项，获取其视觉宽度
        $visualWidths[$i] = Get-VisualWidth $Items[$i].Name #获取每一项的视觉宽度
    }

    $bestCols = 1 #最佳列数
    $bestRows = $count #最佳行数
    $bestColMax = [int[]]::new(1) #创建一个长度为1的整数数组,这里存放每一列的最大视觉宽度
    $bestColMax[0] = ($visualWidths | Measure-Object -Maximum).Maximum

    # maxTryCols = min(文件数, max(1, 终端宽度))
    # 即：尝试的列数不会超过文件总数，也不会超过终端宽度
    $maxTryCols = [Math]::Min($count, [Math]::Max(1, $Width))
    for ($cols = $maxTryCols; $cols -ge 1; $cols--) {
        $rows = [int][Math]::Ceiling($count / [double]$cols)
        $colMax = [int[]]::new($cols)

        for ($i = 0; $i -lt $count; $i++) {
            # 先竖后横：第 i 项落在 col = floor(i / rows)
            $col = [int][Math]::Floor($i / [double]$rows)
            if ($visualWidths[$i] -gt $colMax[$col]) {
                $colMax[$col] = $visualWidths[$i]
            }
        }

        $total = 0
        for ($c = 0; $c -lt $cols; $c++) {
            if ($c -lt $cols - 1) {
                $total += $colMax[$c] + 2
            }
            else {
                $total += $colMax[$c]
            }
        }

        if ($total -le $Width) {
            $bestCols = $cols
            $bestRows = $rows
            $bestColMax = $colMax
            break
        }
    }

    for ($row = 0; $row -lt $bestRows; $row++) {
        for ($col = 0; $col -lt $bestCols; $col++) {
            $index = $col * $bestRows + $row
            if ($index -ge $count) { break }

            $rgb = Get-ItemColor $Items[$index]
            Write-RGB -Text $Items[$index].Name -R $rgb[0] -G $rgb[1] -B $rgb[2] -NoNewline

            # 判断本行后面是否还有项，决定是否补列间距
            $hasMoreInRow = $false
            for ($nextCol = $col + 1; $nextCol -lt $bestCols; $nextCol++) {
                if (($nextCol * $bestRows + $row) -lt $count) {
                    $hasMoreInRow = $true
                    break
                }
            }

            if ($hasMoreInRow) {
                $paddingCount = ($bestColMax[$col] + 2) - $visualWidths[$index]
                if ($paddingCount -gt 0) {
                    Write-Host (' ' * $paddingCount) -NoNewline
                }
            }
        }
        Write-Host ''
    }
}

Remove-Item -Force alias:ls -ErrorAction SilentlyContinue #删除ls别名
# -Option AllScope 表示在所有作用域中都有效
# -Force 表示如果别名已存在，则覆盖它
Set-Alias -Name ls -Value ls-horizontal -Option AllScope -Force #设置ls别名
