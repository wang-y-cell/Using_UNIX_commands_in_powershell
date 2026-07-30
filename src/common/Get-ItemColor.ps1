# 获取文件颜色（返回 RGB 数组）
function Get-ItemColor {
    param($item)
    if ($item.PSIsContainer) {
        return @(97, 175, 239) # Ubuntu 深蓝
    }
    switch -Regex ($item.Extension) {
        '\.(exe|bat|ps1)$' { return @(152, 195, 121) }   # 深绿
        '\.(zip|7z|rar|tar|gz)$' { return @(224, 108, 117) } # 品红
        '\.(jpg|png|gif)$' {return @(255, 85, 255)} #品红
        default { return @(220, 223, 228) }           # 纯白
    }
}
