# dirname（简单函数 + $args）
# 支持：dirname NAME...
# 例：dirname C:\foo\bar.txt
#     dirname ./src/cat/cat.ps1
#     dirname bar.txt
function dirname {
    $names = @(Get-UnixPathArgs -Arguments $args)
    $names = @(Expand-UnixGlob -Path $names)
    if ($names.Count -eq 0) {
        Write-Error 'dirname: missing operand'
        return
    }

    foreach ($name in $names) {
        if ([string]::IsNullOrEmpty($name)) {
            Write-Output '.'
            continue
        }

        $trimmed = $name.TrimEnd('\', '/')
        if ([string]::IsNullOrEmpty($trimmed)) {
            # 根路径
            if ($name -match '^[A-Za-z]:\\?$') {
                Write-Output ($name.Substring(0, 2).TrimEnd('\') + '\')
            } else {
                Write-Output '\'
            }
            continue
        }

        $parent = [System.IO.Path]::GetDirectoryName($trimmed)
        if ([string]::IsNullOrEmpty($parent)) {
            Write-Output '.'
        } else {
            Write-Output $parent
        }
    }
}
