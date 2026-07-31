# which（简单函数 + $args）
# 支持：which [-a] NAME...
# 例：which git
#     which -a ls
#     which pwd grep
function which {
    $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
    $names = @(Get-UnixPathArgs -Arguments $args)
    $all = $flags -contains 'a'

    if ($names.Count -eq 0) {
        Write-Error 'which: missing operand'
        return
    }

    foreach ($name in $names) {
        try {
            $cmds = if ($all) {
                @(Get-Command -Name $name -All -ErrorAction Stop)
            } else {
                @(Get-Command -Name $name -ErrorAction Stop | Select-Object -First 1)
            }
        } catch {
            Write-Error "which: no ${name} in path / functions / aliases"
            continue
        }

        foreach ($cmd in $cmds) {
            switch ($cmd.CommandType) {
                'Application' {
                    Write-Output $cmd.Source
                }
                'ExternalScript' {
                    Write-Output $cmd.Source
                }
                'Alias' {
                    $target = $cmd.Definition
                    Write-Output "${name}: aliased to ${target}"
                }
                'Function' {
                    # 优先显示定义所在脚本
                    $file = $null
                    try {
                        $info = Get-Command -Name $name -CommandType Function -ErrorAction SilentlyContinue
                        if ($info -and $info.ScriptBlock -and $info.ScriptBlock.File) {
                            $file = $info.ScriptBlock.File
                        }
                    } catch { }
                    if ($file) {
                        Write-Output $file
                    } else {
                        Write-Output "${name}: shell function"
                    }
                }
                'Cmdlet' {
                    Write-Output "$($cmd.ModuleName)\$($cmd.Name)"
                }
                default {
                    if ($cmd.Source) {
                        Write-Output $cmd.Source
                    } else {
                        Write-Output "$($cmd.CommandType): ${name}"
                    }
                }
            }
        }
    }
}
