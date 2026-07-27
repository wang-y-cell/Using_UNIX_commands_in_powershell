# 计算视觉宽度（解决中文对齐）
function Get-VisualWidth {
    param([string]$str)
    $visualWidth = 0
    foreach ($char in $str.ToCharArray()) {
        # CJK 统一汉字范围
        if ([int]$char -ge 0x4E00 -and [int]$char -le 0x9FFF) {
            $visualWidth += 2
        } else {
            $visualWidth += 1
        }
    }
    return $visualWidth
}
