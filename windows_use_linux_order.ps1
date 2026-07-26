# ==========================================
# 1. 辅助函数：使用 ANSI 转义序列输出任意 RGB 颜色
# ==========================================
function Write-RGB {
    param(
        [string]$Text,
        [int]$R,
        [int]$G,
        [int]$B,
        [switch]$NoNewline # 开关参数语法。switch 类型的参数不需要赋值，当用户在调用函数时加上 -NoNewline，该参数值为 $True；不加则为 $False。
    )
    # ANSI 24位真彩色代码: \e[38;2;R;G;Bm
    $ansiCode = "$([char]27)[38;2;$R;$G;${B}m"
    $resetCode = "$([char]27)[0m"
    
    if ($NoNewline) {
        Write-Host "${ansiCode}${Text}${resetCode}" -NoNewline
    } else {
        Write-Host "${ansiCode}${Text}${resetCode}"
    }
}

# ==========================================
# 2. 辅助函数：计算视觉宽度 (解决中文对齐)
# ==========================================
function Get-VisualWidth {
    param([string]$str)
    $visualWidth = 0
    foreach ($char in $str.ToCharArray()) {
        # CJK 统一汉字范围,以下是中文咋unicode中的范围
        if ([int]$char -ge 0x4E00 -and [int]$char -le 0x9FFF) {
            $visualWidth += 2
        } else {
            $visualWidth += 1
        }
    }
    return $visualWidth
}

# ==========================================
# 3. 辅助函数：获取文件颜色 (返回 RGB 数组)
# ==========================================
function Get-ItemColor {
    param($item)
    if ($item.PSIsContainer) { 
        return @(97, 175, 239) # Ubuntu 深蓝
    }
    switch -Regex ($item.Extension) {
        '\.(exe|bat|ps1)$' { return @(152, 195, 121) }   # 深绿
        '\.(zip|7z|rar|tar|gz)$' { return @(224, 108, 117) } # 品红
        default { return @(220, 223, 228) }           # 纯白
    }
}

# ==========================================
# 4. 自定义终端提示符 (Prompt)
# ==========================================
function prompt {
    $path = $ExecutionContext.SessionState.Path.CurrentLocation
    
    # 用户名@主机名 (绿色)
    Write-Host "windows@PS:" -ForegroundColor Green -NoNewline
    
    # 路径 (深蓝)
    Write-RGB -Text "$path" -R 97 -G 175 -B 239 -NoNewline
    
    # 分隔符 (白色)
    Write-Host " $" -ForegroundColor White -NoNewline
    
    return " "
}

# ==========================================
# 5. 辅助函数：文件大小可读化 (供 ls / 其他函数复用)
# ==========================================
function Format-FileSize {
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Bytes,

        [switch]$HumanReadable,

        # 输出字段宽度，便于表格对齐；0 表示不填充
        [int]$Width = 0
    )

    if ($null -eq $Bytes) {
        $text = if ($HumanReadable) { '-' } else { '' }
    } elseif (-not $HumanReadable) {
        $text = [string][long]$Bytes
    } else {
        $units = @('B', 'K', 'M', 'G', 'T', 'P')
        $size = [double][long]$Bytes
        $unitIndex = 0
        while ($size -ge 1024 -and $unitIndex -lt ($units.Length - 1)) {
            $size /= 1024
            $unitIndex++
        }
        if ($unitIndex -eq 0) {
            $text = "{0}{1}" -f [int]$size, $units[$unitIndex]
        } elseif ($size -ge 10) {
            $text = "{0:N0}{1}" -f $size, $units[$unitIndex]
        } else {
            $text = "{0:N1}{1}" -f $size, $units[$unitIndex]
        }
    }

    if ($Width -gt 0) {
        return $text.PadLeft($Width)
    }
    return $text
}

# ==========================================
# 6. 核心功能：智能 ls (横向 / 长列表，支持组合参数)
# ==========================================
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
        $sizeWidth = if ($humanReadable) { 6 } else { 12 }
        foreach ($item in $items) {
            $rgb = Get-ItemColor $item
            $timeText = $item.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
            $sizeBytes = if ($item.PSIsContainer) { $null } else { $item.Length }
            $sizeText = Format-FileSize -Bytes $sizeBytes -HumanReadable:$humanReadable -Width $sizeWidth

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

# ==========================================
# 7. 别名设置与 ll 命令增强
# ==========================================
Remove-Item alias:ls -ErrorAction SilentlyContinue
Set-Alias -Name ls -Value ls-horizontal -Option AllScope -Force

function ll {
    # 固定等价于 ls -alh（显示隐藏 + 长列表 + 可读大小）
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$RemainingArguments
    )
    if ($RemainingArguments -and $RemainingArguments.Count -gt 0) {
        ls-horizontal -alh @RemainingArguments
    } else {
        ls-horizontal -alh
    }
}

# ==========================================
# 8. Linux 风格 find（-name/-iname/-type/-mtime/-size ...）
# ==========================================
function Convert-FindSizeSpec {
    param([Parameter(Mandatory = $true)][string]$Spec)

    if ($Spec -notmatch '^([+-]?)(\d+)([bcCkKmMgG]?)$') {
        throw "无效的 -size 参数: $Spec  （示例: +100M, -10k, 512）"
    }

    $op = $Matches[1]
    $num = [long]$Matches[2]
    $unit = $Matches[3]

    $bytes = switch -CaseSensitive ($unit) {
        'b' { $num }
        'c' { $num }
        'C' { $num }
        'k' { $num * 1KB }
        'K' { $num * 1KB }
        'm' { $num * 1MB }
        'M' { $num * 1MB }
        'g' { $num * 1GB }
        'G' { $num * 1GB }
        default { $num * 512 } # 与 GNU find 默认 512 字节块一致
    }

    return [pscustomobject]@{ Op = $op; Bytes = $bytes }
}

function Convert-FindTimeSpec {
    param([Parameter(Mandatory = $true)][string]$Spec)

    if ($Spec -notmatch '^([+-]?)(\d+)$') {
        throw "无效的时间参数: $Spec  （示例: -1, +30, 7）"
    }

    return [pscustomobject]@{ Op = $Matches[1]; N = [double]$Matches[2] }
}

function Test-FindNumericFilter {
    param(
        [double]$Value,
        [string]$Op,
        [double]$N
    )

    switch ($Op) {
        '+' { return $Value -gt $N }
        '-' { return $Value -lt $N }
        default { return [Math]::Floor($Value) -eq $N }
    }
}

function Test-FindIsSymlink {
    param($Item)
    if ($null -ne $Item.LinkType -and $Item.LinkType -eq 'SymbolicLink') {
        return $true
    }
    # 兼容部分环境未填充 LinkType 的情况
    try {
        return [bool]($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and -not $Item.PSIsContainer
    } catch {
        return $false
    }
}

function find {
    <#
    .SYNOPSIS
        Linux 风格的文件查找（常用子集）
    .EXAMPLE
        find . -name "*.txt"
        find . -iname "*.TXT" -type f
        find . -type d -mtime -1
        find . -type f -size +100M
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Path = '.',

        [string]$name,
        [string]$iname,

        [ValidateSet('f', 'd', 'l', 'F', 'D', 'L')]
        [string]$type,

        # 修改时间：天 / 分钟
        [string]$mtime,
        [string]$mmin,
        # 访问时间：天（Windows: LastAccessTime）
        [string]$atime,
        # 状态变更：天（Windows 近似为 CreationTime）
        [string]$ctime,

        [string]$size
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Error "路径不存在: $Path"
        return
    }

    $sizeFilter = $null
    if ($PSBoundParameters.ContainsKey('size')) {
        $sizeFilter = Convert-FindSizeSpec -Spec ([string]$size)
    }

    $mtimeFilter = if ($PSBoundParameters.ContainsKey('mtime')) { Convert-FindTimeSpec -Spec ([string]$mtime) } else { $null }
    $mminFilter  = if ($PSBoundParameters.ContainsKey('mmin'))  { Convert-FindTimeSpec -Spec ([string]$mmin) }  else { $null }
    $atimeFilter = if ($PSBoundParameters.ContainsKey('atime')) { Convert-FindTimeSpec -Spec ([string]$atime) } else { $null }
    $ctimeFilter = if ($PSBoundParameters.ContainsKey('ctime')) { Convert-FindTimeSpec -Spec ([string]$ctime) } else { $null }

    $namePattern = $null
    if ($name) {
        $namePattern = [Management.Automation.WildcardPattern]::new($name, [Management.Automation.WildcardOptions]::None)
    }
    $inamePattern = $null
    if ($iname) {
        $inamePattern = [Management.Automation.WildcardPattern]::new(
            $iname,
            [Management.Automation.WildcardOptions]::IgnoreCase
        )
    }

    $typeKey = if ($type) { $type.ToLowerInvariant() } else { $null }
    $now = Get-Date

    $root = Get-Item -LiteralPath $Path -Force
    $items = @($root) + @(
        Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    )

    foreach ($item in $items) {
        # --- 类型 ---
        if ($typeKey) {
            $isLink = Test-FindIsSymlink -Item $item
            $isDir = $item.PSIsContainer -and -not $isLink
            $isFile = -not $item.PSIsContainer -and -not $isLink
            $matchType = switch ($typeKey) {
                'f' { $isFile }
                'd' { $isDir }
                'l' { $isLink }
                default { $true }
            }
            if (-not $matchType) { continue }
        }

        # --- 名称 ---
        if ($namePattern -and -not $namePattern.IsMatch($item.Name)) { continue }
        if ($inamePattern -and -not $inamePattern.IsMatch($item.Name)) { continue }

        # --- 时间 ---
        if ($mtimeFilter) {
            $ageDays = ($now - $item.LastWriteTime).TotalDays
            if (-not (Test-FindNumericFilter -Value $ageDays -Op $mtimeFilter.Op -N $mtimeFilter.N)) { continue }
        }
        if ($mminFilter) {
            $ageMins = ($now - $item.LastWriteTime).TotalMinutes
            if (-not (Test-FindNumericFilter -Value $ageMins -Op $mminFilter.Op -N $mminFilter.N)) { continue }
        }
        if ($atimeFilter) {
            $ageDays = ($now - $item.LastAccessTime).TotalDays
            if (-not (Test-FindNumericFilter -Value $ageDays -Op $atimeFilter.Op -N $atimeFilter.N)) { continue }
        }
        if ($ctimeFilter) {
            # Windows 无 Unix ctime，这里用创建Time 近似
            $ageDays = ($now - $item.CreationTime).TotalDays
            if (-not (Test-FindNumericFilter -Value $ageDays -Op $ctimeFilter.Op -N $ctimeFilter.N)) { continue }
        }

        # --- 大小（目录跳过 size 过滤，与常见用法一致）---
        if ($sizeFilter) {
            if ($item.PSIsContainer) { continue }
            $len = [long]$item.Length
            $ok = switch ($sizeFilter.Op) {
                '+' { $len -gt $sizeFilter.Bytes }
                '-' { $len -lt $sizeFilter.Bytes }
                default { $len -eq $sizeFilter.Bytes }
            }
            if (-not $ok) { continue }
        }

        # 输出完整路径（接近 Linux find）
        $item.FullName
    }
}

# ==========================================
# 9. Linux 风格：mkdir / touch / pwd / rm / cp / mv
# ==========================================
function Merge-UnixFlagLetters {
    param(
        [string]$Seed = '',
        [string[]]$ExtraSwitches,
        [object[]]$RemainingArguments,
        [string]$AllowedPattern = '[a-zA-Z]'
    )

    $flagText = $Seed
    foreach ($sw in @($ExtraSwitches)) {
        if ($sw) { $flagText += $sw }
    }

    $pathArgs = [System.Collections.Generic.List[string]]::new()
    foreach ($arg in @($RemainingArguments)) {
        if ($null -eq $arg) { continue }
        $text = [string]$arg
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        if ($text -match "^-$AllowedPattern+$") {
            $flagText += $text.TrimStart('-')
            continue
        }
        $pathArgs.Add($text)
    }

    return [pscustomobject]@{
        Flags = $flagText
        Paths = $pathArgs.ToArray()
    }
}

# --- pwd ---
Remove-Item alias:pwd -ErrorAction SilentlyContinue
function pwd {
    param([switch]$P)
    $path = (Get-Location).Path
    if ($P) {
        try { return (Get-Item -LiteralPath $path).FullName }
        catch { return $path }
    }
    return $path
}

# --- mkdir (-p 创建父目录；目录已存在时不报错) ---
Remove-Item alias:mkdir -ErrorAction SilentlyContinue
Remove-Item function:mkdir -ErrorAction SilentlyContinue
function mkdir {
    param(
        [Alias('parents')]
        [switch]$p,
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$RemainingArguments
    )

    $parsed = Merge-UnixFlagLetters -Seed '' -ExtraSwitches @(
        $(if ($p) { 'p' } else { '' })
    ) -RemainingArguments $RemainingArguments -AllowedPattern '[p]'

    $makeParents = $parsed.Flags.Contains('p')
    if ($parsed.Paths.Count -eq 0) {
        Write-Error 'mkdir: missing operand'
        return
    }

    foreach ($dir in $parsed.Paths) {
        if (Test-Path -LiteralPath $dir) {
            if (-not $makeParents) {
                Write-Error "mkdir: cannot create directory '${dir}': File exists"
            }
            continue
        }

        try {
            if ($makeParents) {
                New-Item -Path $dir -ItemType Directory -Force -ErrorAction Stop | Out-Null
            } else {
                $parent = Split-Path -Parent $dir
                if ($parent -and -not (Test-Path -LiteralPath $parent)) {
                    Write-Error "mkdir: cannot create directory '${dir}': No such file or directory"
                    continue
                }
                New-Item -Path $dir -ItemType Directory -ErrorAction Stop | Out-Null
            }
        } catch {
            Write-Error "mkdir: cannot create directory '${dir}': $($_.Exception.Message)"
        }
    }
}

# --- touch (-c 不创建，仅更新已存在文件的时间戳) ---
function touch {
    param(
        [Alias('no-create')]
        [switch]$c,
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$RemainingArguments
    )

    $parsed = Merge-UnixFlagLetters -Seed '' -ExtraSwitches @(
        $(if ($c) { 'c' } else { '' })
    ) -RemainingArguments $RemainingArguments -AllowedPattern '[c]'

    $noCreate = $parsed.Flags.Contains('c')
    if ($parsed.Paths.Count -eq 0) {
        Write-Error 'touch: missing file operand'
        return
    }

    $now = Get-Date
    foreach ($path in $parsed.Paths) {
        if (Test-Path -LiteralPath $path) {
            try {
                $item = Get-Item -LiteralPath $path -Force
                $item.LastAccessTime = $now
                $item.LastWriteTime = $now
            } catch {
                Write-Error "touch: cannot touch '${path}': $($_.Exception.Message)"
            }
            continue
        }

        if ($noCreate) { continue }

        try {
            $parent = Split-Path -Parent $path
            if ($parent -and -not (Test-Path -LiteralPath $parent)) {
                Write-Error "touch: cannot touch '${path}': No such file or directory"
                continue
            }
            New-Item -Path $path -ItemType File -ErrorAction Stop | Out-Null
        } catch {
            Write-Error "touch: cannot touch '${path}': $($_.Exception.Message)"
        }
    }
}

# --- rm (-r/-R 递归, -f 强制, 支持 -rf/-fr；PS 参数不区分大小写) ---
Remove-Item alias:rm -ErrorAction SilentlyContinue
function rm {
    param(
        # -r/-R 相同（PS 参数名不区分大小写）
        [switch]$r,
        [switch]$f,
        [Alias('fr')]
        [switch]$rf,
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$RemainingArguments
    )

    $seed = ''
    if ($r) { $seed += 'r' }
    if ($f) { $seed += 'f' }
    if ($rf) { $seed += 'rf' }

    $parsed = Merge-UnixFlagLetters -Seed $seed -RemainingArguments $RemainingArguments -AllowedPattern '[rfRF]'
    $recursive = $parsed.Flags -match '[rR]'
    $force = $parsed.Flags.ToLowerInvariant().Contains('f')

    if ($parsed.Paths.Count -eq 0) {
        Write-Error 'rm: missing operand'
        return
    }

    foreach ($path in $parsed.Paths) {
        if (-not (Test-Path -LiteralPath $path)) {
            if (-not $force) {
                Write-Error "rm: cannot remove '${path}': No such file or directory"
            }
            continue
        }

        $item = Get-Item -LiteralPath $path -Force
        if ($item.PSIsContainer -and -not $recursive) {
            Write-Error "rm: cannot remove '${path}': Is a directory"
            continue
        }

        try {
            $riParams = @{
                LiteralPath = $path
                Recurse     = $recursive
                Force       = $true
                ErrorAction = $(if ($force) { 'SilentlyContinue' } else { 'Stop' })
            }
            Remove-Item @riParams
        } catch {
            if (-not $force) {
                Write-Error "rm: cannot remove '${path}': $($_.Exception.Message)"
            }
        }
    }
}

# --- cp (-r/-R 递归, -f 覆盖, -v 详细, 支持 -rf/-rv 等) ---
Remove-Item alias:cp -ErrorAction SilentlyContinue
function cp {
    param(
        # -r/-R 相同（PS 参数名不区分大小写）
        [switch]$r,
        [switch]$f,
        [switch]$v,
        [Alias('fr')]
        [switch]$rf,
        [Alias('vr')]
        [switch]$rv,
        [Alias('vf')]
        [switch]$fv,
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$RemainingArguments
    )

    $seed = ''
    if ($r) { $seed += 'r' }
    if ($f) { $seed += 'f' }
    if ($v) { $seed += 'v' }
    if ($rf) { $seed += 'rf' }
    if ($rv) { $seed += 'rv' }
    if ($fv) { $seed += 'fv' }

    $parsed = Merge-UnixFlagLetters -Seed $seed -RemainingArguments $RemainingArguments -AllowedPattern '[rRfFvV]'
    $flagsLower = $parsed.Flags.ToLowerInvariant()
    $recursive = $flagsLower.Contains('r')
    $force = $flagsLower.Contains('f')
    $verbose = $flagsLower.Contains('v')

    if ($parsed.Paths.Count -lt 2) {
        Write-Error 'cp: missing file operand'
        return
    }

    $dest = $parsed.Paths[-1]
    $sources = $parsed.Paths[0..($parsed.Paths.Length - 2)]

    if ($sources.Count -gt 1) {
        if (-not (Test-Path -LiteralPath $dest) -or -not (Get-Item -LiteralPath $dest).PSIsContainer) {
            Write-Error "cp: target '${dest}' is not a directory"
            return
        }
    }

    foreach ($src in $sources) {
        if (-not (Test-Path -LiteralPath $src)) {
            Write-Error "cp: cannot stat '${src}': No such file or directory"
            continue
        }

        $srcItem = Get-Item -LiteralPath $src -Force
        if ($srcItem.PSIsContainer -and -not $recursive) {
            Write-Error "cp: -r not specified; omitting directory '${src}'"
            continue
        }

        try {
            Copy-Item -LiteralPath $src -Destination $dest -Recurse:$recursive -Force:$force -ErrorAction Stop
            if ($verbose) {
                Write-Host "'${src}' -> '${dest}'"
            }
        } catch {
            Write-Error "cp: cannot copy '${src}' to '${dest}': $($_.Exception.Message)"
        }
    }
}

# --- mv (-f 覆盖, -v 详细) ---
Remove-Item alias:mv -ErrorAction SilentlyContinue
function mv {
    param(
        [switch]$f,
        [switch]$v,
        [Alias('vf')]
        [switch]$fv,
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$RemainingArguments
    )

    $seed = ''
    if ($f) { $seed += 'f' }
    if ($v) { $seed += 'v' }
    if ($fv) { $seed += 'fv' }

    $parsed = Merge-UnixFlagLetters -Seed $seed -RemainingArguments $RemainingArguments -AllowedPattern '[fFvV]'
    $flagsLower = $parsed.Flags.ToLowerInvariant()
    $force = $flagsLower.Contains('f')
    $verbose = $flagsLower.Contains('v')

    if ($parsed.Paths.Count -lt 2) {
        Write-Error 'mv: missing file operand'
        return
    }

    $dest = $parsed.Paths[-1]
    $sources = $parsed.Paths[0..($parsed.Paths.Length - 2)]

    if ($sources.Count -gt 1) {
        if (-not (Test-Path -LiteralPath $dest) -or -not (Get-Item -LiteralPath $dest).PSIsContainer) {
            Write-Error "mv: target '${dest}' is not a directory"
            return
        }
    }

    foreach ($src in $sources) {
        if (-not (Test-Path -LiteralPath $src)) {
            Write-Error "mv: cannot stat '${src}': No such file or directory"
            continue
        }

        try {
            Move-Item -LiteralPath $src -Destination $dest -Force:$force -ErrorAction Stop
            if ($verbose) {
                Write-Host "'${src}' -> '${dest}'"
            }
        } catch {
            Write-Error "mv: cannot move '${src}' to '${dest}': $($_.Exception.Message)"
        }
    }
}