# 按依赖顺序加载全部模块（开发态 / 安装态共用）
# 用法: . .\load.ps1

$script:UucipRoot = $PSScriptRoot # 项目根目录

# 加载顺序
$script:UucipLoadOrder = @(
    # 公共辅助（编码须最先，保证后续脚本中文输出正常）
    'common\Set-ConsoleUtf8.ps1'
    'common\Write-RGB.ps1'
    'common\Get-VisualWidth.ps1'
    'common\Get-ItemColor.ps1'
    'common\Format-FileSize.ps1'
    'common\Get-UnixShortFlagChars.ps1'
    'common\Merge-UnixFlagLetters.ps1'
    'common\Expand-UnixGlob.ps1'
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
    'head\head.ps1'
    'tail\tail.ps1'
    'wc\wc.ps1'
    'tee\tee.ps1'
    'sort\sort.ps1'
    'uniq\uniq.ps1'
    'basename\basename.ps1'
    'dirname\dirname.ps1'
    'tree\tree.ps1'
    'du\du.ps1'
    'df\df.ps1'
    'ln\ln.ps1'
    'diff\diff.ps1'
    'which\which.ps1'
    'clear\clear.ps1'
    'pwd\pwd.ps1'
    'mkdir\mkdir.ps1'
    'touch\touch.ps1'
    'rm\rm.ps1'
    'cp\cp.ps1'
    'mv\mv.ps1'
)

# 按顺序加载模块
foreach ($rel in $script:UucipLoadOrder) {
    $full = Join-Path $script:UucipRoot $rel
    if (-not (Test-Path -LiteralPath $full)) {
        Write-Error "缺少文件: $full"
        continue
    }
    . $full
}
