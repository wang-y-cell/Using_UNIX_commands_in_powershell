# 智能 ls（横向 / 长列表，支持组合参数）
# 使用简单函数（无 param），未声明的 -al/-lh 等会进入 $args，再交给短选项解析
function ls-horizontal {
    $flags = @(Get-UnixShortFlagChars -Arguments $args) # 获得短选项
    $pathArgs = @(Get-UnixPathArgs -Arguments $args) # 获得路径参数

    $showAll = $flags -contains 'a' # 显示所有文件
    $longFormat = $flags -contains 'l' # 长列表模式
    $humanReadable = $flags -contains 'h' # 人类可读模式

    # -h 仅在长列表中有意义；单独 -h 时按 -lh 处理
    if ($humanReadable -and -not $longFormat) { 
        # 如果人类可读模式为true，且长列表模式为false，则设置长列表模式为true
        $longFormat = $true
    }

    $gciParams = @{
        ErrorAction = 'SilentlyContinue'
    }
    if ($showAll) {
        $gciParams.Force = $true
    }
    if ($pathArgs.Count -gt 0) {
        $gciParams.Path = [string[]]$pathArgs
    }

    $items = Get-ChildItem @gciParams

    # 过滤以 . 开头的隐藏项（Unix 风格）
    if (-not $showAll) {
        $items = $items | Where-Object { $_.Name -notlike '.*' }
    }

    if (-not $items) { return }

    # 管道输出：向成功流写入名称，供 grep 等下游使用（如 ls | grep txt）
    $pipingOut = $MyInvocation.PipelinePosition -lt $MyInvocation.PipelineLength
    if ($pipingOut) {
        foreach ($item in @($items)) {
            $item.Name
        }
        return
    }

    # --- 长列表模式：ls -l / -lh / -al / -alh ---
    if ($longFormat) {
        # 先格式化全部大小，按最长文本定列宽，避免固定宽度留白过多
        $sizeTexts = @(foreach ($item in $items) {
            $sizeBytes = if ($item.PSIsContainer) { $null } else { $item.Length }
            Format-FileSize -Bytes $sizeBytes -HumanReadable:$humanReadable
        })
        $sizeWidth = 1
        foreach ($st in $sizeTexts) {
            if ($st.Length -gt $sizeWidth) { $sizeWidth = $st.Length }
        }

        $i = 0
        foreach ($item in $items) {
            $rgb = Get-ItemColor $item
            # Windows Mode：与 Linux 权限位同位置，如 d----- / -a---- / -ar---
            $modeText = if ($null -ne $item.Mode -and $item.Mode -ne '') { $item.Mode } else { '------' }
            $timeText = $item.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
            $sizeText = $sizeTexts[$i].PadLeft($sizeWidth)
            $i++

            Write-RGB -Text "$modeText  " -R $BLUE[0] -G $BLUE[1] -B $BLUE[2] -NoNewline
            Write-RGB -Text "$timeText  " -R $GRAY[0] -G $GRAY[1] -B $GRAY[2] -NoNewline
            Write-RGB -Text "$sizeText  " -R $DARK_GRAY[0] -G $DARK_GRAY[1] -B $DARK_GRAY[2] -NoNewline
            Write-RGB -Text $item.Name -R $rgb[0] -G $rgb[1] -B $rgb[2]
        }
        return
    }

    # --- 横向多列模式（默认）---
    $width = $Host.UI.RawUI.WindowSize.Width
    # 其它策略保留，暂不调用：
    # Format-LsHorizontalUniform -Items $items -Width $width
    # Format-LsHorizontalPerColumn -Items $items -Width $width
    Format-LsColumnMajor -Items $items -Width $width
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

Remove-Item alias:ls -ErrorAction SilentlyContinue #删除ls别名
# -Option AllScope 表示在所有作用域中都有效
# -Force 表示如果别名已存在，则覆盖它
Set-Alias -Name ls -Value ls-horizontal -Option AllScope -Force #设置ls别名
