# 自定义终端提示符
function prompt {
    $path = $ExecutionContext.SessionState.Path.CurrentLocation.Path
    $displayPath = Format-PromptPath -Path $path

    # 用户名@主机名 (绿色)
    Write-Host "windows@PS:" -ForegroundColor Green -NoNewline

    # 路径：文件夹名深蓝，分隔符白色
    $segments = $displayPath -split '/'
    for ($i = 0; $i -lt $segments.Count; $i++) {
        if ($i -gt 0) {
            Write-RGB -Text '/' -R 255 -G 255 -B 255 -NoNewline
        }
        if ($segments[$i] -ne '') {
            Write-RGB -Text $segments[$i] -R 97 -G 175 -B 239 -NoNewline
        }
    }

    # 分隔符 (白色)
    Write-Host " $" -ForegroundColor White -NoNewline

    return " "
}
