# 使用 ANSI 转义序列输出任意 RGB 颜色
function Write-RGB {
    param(
        [string]$Text,
        [int]$R,
        [int]$G,
        [int]$B,
        [switch]$NoNewline
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
