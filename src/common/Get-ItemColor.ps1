$GREEN = @(152, 195, 121)
$BLUE = @(97, 175, 239)
$RED = @(224, 108, 117)
$PURPLE = @(255, 85, 255)
$WHITE = @(220, 223, 228)
$GRAY = @(192, 192, 192)
$DARK_GRAY = @(128, 128, 128)


# 获取文件颜色（返回 RGB 数组）
function Get-ItemColor {
    param($item)
    if ($item.PSIsContainer) {
        return $BLUE # Ubuntu 深蓝
    }
    switch -Regex ($item.Extension) {
        '\.(exe|bat|ps1)$' { return $GREEN }   # 深绿
        '\.(zip|7z|rar|tar|gz)$' { return $RED } # 品红
        '\.(jpg|png|gif)$' {return $PURPLE} #品红
        default { return $WHITE }           # 纯白
    }
}
