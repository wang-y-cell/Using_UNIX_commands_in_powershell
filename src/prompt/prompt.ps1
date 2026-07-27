# 自定义终端提示符
function prompt {
    $path = $ExecutionContext.SessionState.Path.CurrentLocation

    # 用户名@主机名 (绿色)
    Write-Host "windows@PS:" -ForegroundColor Green -NoNewline

    # 路径 (深蓝)
    Write-RGB -Text "$path" -R 97 -G 175 -B 239 -NoNewline

    # 分隔符 (白色)
    Write-Host " $" -ForegroundColor White -NoNewline

    return " "
}
