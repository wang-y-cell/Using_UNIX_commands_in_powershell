# 智能 ls（横向 / 长列表，支持组合参数）
# PowerShell 会把 -al / -lh 解析为参数名，故需显式声明各组合开关
function ls-horizontal {
    param(
        [switch]$a,
        [switch]$l,
        [switch]$h,
        [switch]$al,
        [switch]$la,
        [switch]$lh,
        [switch]$hl,
        [switch]$ah,
        [switch]$ha,
        [switch]$alh,
        [switch]$ahl,
        [switch]$lah,
        [switch]$lha,
        [switch]$hal,
        [switch]$hla,
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$RemainingArguments
    )

    # 合并独立开关与组合开关：支持 ls -l -a / ls -al / ls -lh 等
    $flagText = ''
    if ($a)   { $flagText += 'a' }
    if ($l)   { $flagText += 'l' }
    if ($h)   { $flagText += 'h' }
    if ($al)  { $flagText += 'al' }
    if ($la)  { $flagText += 'la' }
    if ($lh)  { $flagText += 'lh' }
    if ($hl)  { $flagText += 'hl' }
    if ($ah)  { $flagText += 'ah' }
    if ($ha)  { $flagText += 'ha' }
    if ($alh) { $flagText += 'alh' }
    if ($ahl) { $flagText += 'ahl' }
    if ($lah) { $flagText += 'lah' }
    if ($lha) { $flagText += 'lha' }
    if ($hal) { $flagText += 'hal' }
    if ($hla) { $flagText += 'hla' }

    # 也接受位置参数形式：ls '-al'、ls --% -al
    $pathArgs = [System.Collections.Generic.List[object]]::new()
    foreach ($arg in @($RemainingArguments)) {
        if ($null -eq $arg) { continue }
        $argText = [string]$arg
        if ([string]::IsNullOrWhiteSpace($argText)) { continue }
        if ($argText -match '^-[alh]+$') {
            $flagText += $argText.TrimStart('-')
            continue
        }
        $pathArgs.Add($arg)
    }

    $showAll = $flagText.Contains('a')
    $longFormat = $flagText.Contains('l')
    $humanReadable = $flagText.Contains('h')

    # -h 仅在长列表中有意义；单独 -h 时按 -lh 处理
    if ($humanReadable -and -not $longFormat) {
        $longFormat = $true
    }

    $gciParams = @{
        ErrorAction = 'SilentlyContinue'
    }
    if ($showAll) {
        $gciParams.Force = $true
    }
    # 无路径时不要传 Path（@RemainingArguments 为空时可能带入 $null）
    if ($pathArgs.Count -gt 0) {
        $gciParams.Path = $pathArgs.ToArray()
    }

    $items = Get-ChildItem @gciParams

    # 过滤以 . 开头的隐藏项（Unix 风格）
    if (-not $showAll) {
        $items = $items | Where-Object { $_.Name -notlike '.*' }
    }

    if (-not $items) { return }

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

            Write-Host "$modeText  " -ForegroundColor Blue -NoNewline
            Write-Host "$timeText  " -ForegroundColor Gray -NoNewline
            Write-Host "$sizeText  " -ForegroundColor DarkGray -NoNewline
            Write-RGB -Text $item.Name -R $rgb[0] -G $rgb[1] -B $rgb[2]
        }
        return
    }

    # --- 横向多列模式（默认）---
    $width = $Host.UI.RawUI.WindowSize.Width
    $maxVisualLen = 0
    foreach ($item in $items) {
        $len = Get-VisualWidth $item.Name
        if ($len -gt $maxVisualLen) { $maxVisualLen = $len }
    }

    if ($maxVisualLen -gt ($width / 2)) {
        foreach ($item in $items) {
            $rgb = Get-ItemColor $item
            Write-RGB -Text $item.Name -R $rgb[0] -G $rgb[1] -B $rgb[2]
        }
        return
    }

    $minColumnWidth = $maxVisualLen + 2
    if ($minColumnWidth -lt 15) { $minColumnWidth = 15 }

    $maxColumns = [Math]::Max(1, [Math]::Floor($width / $minColumnWidth))
    $count = 0

    foreach ($item in $items) {
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

Remove-Item alias:ls -ErrorAction SilentlyContinue
Set-Alias -Name ls -Value ls-horizontal -Option AllScope -Force
