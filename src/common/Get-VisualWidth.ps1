# 计算视觉宽度（解决中文/全角对齐）
# 依据 Unicode East Asian Width：Wide / Fullwidth 计 2，其余计 1
# 原先仅覆盖 CJK 统一汉字 0x4E00-0x9FFF，漏计 《》 ： 、 等全角标点
function Get-VisualWidth {
    param([string]$str) #字符串
    if ([string]::IsNullOrEmpty($str)) { return 0 }

    $visualWidth = 0
    $chars = $str.ToCharArray()
    for ($i = 0; $i -lt $chars.Length; $i++) {
        $c = [int]$chars[$i]

        # UTF-16 代理对（emoji 等）：按宽字符计 2，跳过低位代理
        if ($c -ge 0xD800 -and $c -le 0xDBFF -and ($i + 1) -lt $chars.Length) {
            $low = [int]$chars[$i + 1]
            if ($low -ge 0xDC00 -and $low -le 0xDFFF) {
                $visualWidth += 2
                $i++
                continue
            }
        }

        # East Asian Wide / Fullwidth 常见区间（与多数终端 wcwidth 行为一致）
        $isWide = (
            ($c -ge 0x1100 -and $c -le 0x115F) -or   # Hangul Jamo
            ($c -eq 0x2329 -or $c -eq 0x232A) -or    # 〈 〉
            ($c -ge 0x2E80 -and $c -le 0xA4CF -and $c -ne 0x303F) -or  # CJK 部首/标点/假名/汉字等（《》在 0x3000 区）
            ($c -ge 0xAC00 -and $c -le 0xD7A3) -or   # Hangul 音节
            ($c -ge 0xF900 -and $c -le 0xFAFF) -or   # CJK 兼容汉字
            ($c -ge 0xFE10 -and $c -le 0xFE19) -or   # 竖排标点
            ($c -ge 0xFE30 -and $c -le 0xFE6F) -or   # CJK 兼容形式
            ($c -ge 0xFF00 -and $c -le 0xFF60) -or   # 全角 ASCII（含 ：）
            ($c -ge 0xFFE0 -and $c -le 0xFFE6)       # 全角符号
        )

        if ($isWide) {
            $visualWidth += 2
        }
        else {
            $visualWidth += 1
        }
    }
    return $visualWidth #返回字符串实际的视觉宽度
}
