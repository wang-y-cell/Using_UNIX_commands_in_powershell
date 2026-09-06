# 设置 Unix 风格退出码（供脚本检查 $LASTEXITCODE）
# 约定：0 成功；1 未匹配/有差异等；2 用法或访问错误
function Set-UnixExitCode {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Code
    )
    $global:LASTEXITCODE = $Code
}

function Get-UnixExitCode {
    if ($null -eq $global:LASTEXITCODE) { return 0 }
    return [int]$global:LASTEXITCODE
}
