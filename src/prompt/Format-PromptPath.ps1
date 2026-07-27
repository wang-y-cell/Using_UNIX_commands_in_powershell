# 将路径缩写为适合提示符显示的形式
# 文件夹数 >= 3 时保留盘符与最近两级，中间用 /.../ 省略
function Format-PromptPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $normalized = ($Path -replace '\\', '/').TrimEnd('/')

    # 盘符路径，如 C:/Users/foo
    if ($normalized -match '^([A-Za-z]:)(/.*)?$') {
        $drive = $Matches[1]
        $rest = if ($Matches[2]) { $Matches[2].TrimStart('/') } else { '' }

        if ([string]::IsNullOrEmpty($rest)) {
            return "${drive}/"
        }

        $folders = @($rest -split '/' | Where-Object { $_ -ne '' })

        if ($folders.Count -ge 3) {
            $tail = $folders[($folders.Count - 2)..($folders.Count - 1)]
            return "${drive}/.../$($tail -join '/')"
        }

        return "${drive}/$($folders -join '/')"
    }

    # 其他路径（如 UNC）：按同样规则处理段数
    $parts = @($normalized -split '/' | Where-Object { $_ -ne '' })
    if ($parts.Count -ge 3) {
        $head = $parts[0]
        $tail = $parts[($parts.Count - 2)..($parts.Count - 1)]
        return "$head/.../$($tail -join '/')"
    }

    return ($parts -join '/')
}
