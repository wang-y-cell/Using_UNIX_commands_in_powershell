# 计算视觉宽度（解决中文对齐）
function Get-VisualWidth {
    param([string]$str) #字符串
    $visualWidth = 0
    foreach ($char in $str.ToCharArray()) { #遍历字符串中的每个字符
        # CJK 统一汉字范围
        if ([int]$char -ge 0x4E00 -and [int]$char -le 0x9FFF) {
            $visualWidth += 2
        } else { #如果字符不是中文字符，则宽度加1
            $visualWidth += 1
        }
    }
    return $visualWidth #返回字符串实际的视觉宽度
}
