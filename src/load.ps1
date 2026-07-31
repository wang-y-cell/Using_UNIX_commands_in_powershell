# 按依赖顺序加载全部模块（开发态 / 安装态共用）
# 用法: . .\load.ps1

$script:WuloRoot = $PSScriptRoot # 项目根目录

# 加载顺序
$script:WuloLoadOrder = @(
    # 公共辅助（编码须最先，保证后续脚本中文输出正常）
    'common\Set-ConsoleUtf8.ps1'
    'common\Write-RGB.ps1'
    'common\Get-VisualWidth.ps1'
    'common\Get-ItemColor.ps1'
    'common\Format-FileSize.ps1'
    'common\Get-UnixShortFlagChars.ps1'
    'common\Merge-UnixFlagLetters.ps1'
    # 提示符
    'prompt\Format-PromptPath.ps1'
    'prompt\prompt.ps1'
    # 命令
    'ls\ls.ps1'
    'ls\ll.ps1'
    'find\helpers.ps1'
    'find\find.ps1'
    'grep\grep.ps1'
    'cat\cat.ps1'
    'pwd\pwd.ps1'
    'mkdir\mkdir.ps1'
    'touch\touch.ps1'
    'rm\rm.ps1'
    'cp\cp.ps1'
    'mv\mv.ps1'
)

# 按顺序加载模块
foreach ($rel in $script:WuloLoadOrder) {
    $full = Join-Path $script:WuloRoot $rel
    if (-not (Test-Path -LiteralPath $full)) {
        Write-Error "缺少文件: $full"
        continue
    }
    . $full
}
