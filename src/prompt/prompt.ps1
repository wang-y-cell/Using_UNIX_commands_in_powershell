# 自定义终端提示符
function prompt {
    $path = $ExecutionContext.SessionState.Path.CurrentLocation.Path
    $displayPath = Format-PromptPath -Path $path

    # 用户名@主机名
    Write-RGB -Text 'windows@PS:' -R $GREEN[0] -G $GREEN[1] -B $GREEN[2] -NoNewline

    # 路径：文件夹名用 $BLUE，分隔符用 $WHITE
    $segments = $displayPath -split '/'
    for ($i = 0; $i -lt $segments.Count; $i++) {
        if ($i -gt 0) {
            Write-RGB -Text '/' -R $WHITE[0] -G $WHITE[1] -B $WHITE[2] -NoNewline
        }
        if ($segments[$i] -ne '') {
            Write-RGB -Text $segments[$i] -R $BLUE[0] -G $BLUE[1] -B $BLUE[2] -NoNewline
        }
    }

    # 提示符尾部
    Write-RGB -Text ' $' -R $WHITE[0] -G $WHITE[1] -B $WHITE[2] -NoNewline

    return ' '
}
