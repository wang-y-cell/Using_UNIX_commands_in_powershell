# 文件大小可读化（供 ls / 其他函数复用）
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
        $text = '-'
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
