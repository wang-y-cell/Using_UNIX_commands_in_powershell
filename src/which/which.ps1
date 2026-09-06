# which（简单函数 + $args）
# 支持：which [-a] NAME...
# 优先 PATH 中的可执行文件；再用 Alias/Function（更接近 Linux which 肌肉记忆）
function which {
    $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
    $names = @(Get-UnixPathArgs -Arguments $args)
    $all = $flags -contains 'a'
    $hadError = $false
    Set-UnixExitCode -Code 0

    if ($names.Count -eq 0) {
        Write-Error 'which: missing operand'
        Set-UnixExitCode -Code 1
        return
    }

    foreach ($name in $names) {
        $found = $false
        try {
            $cmds = @(Get-Command -Name $name -All -ErrorAction Stop)
        } catch {
            Write-Error "which: no ${name} in ($env:PATH)"
            $hadError = $true
            continue
        }

        # 先 Application / ExternalScript（PATH），再 Alias/Function/Cmdlet
        $ordered = @(
            $cmds | Where-Object { $_.CommandType -in @('Application', 'ExternalScript') }
        ) + @(
            $cmds | Where-Object { $_.CommandType -notin @('Application', 'ExternalScript') }
        )

        if (-not $all) {
            $ordered = @($ordered | Select-Object -First 1)
        }

        foreach ($cmd in $ordered) {
            $found = $true
            switch ($cmd.CommandType) {
                'Application' { Write-Output $cmd.Source }
                'ExternalScript' { Write-Output $cmd.Source }
                'Alias' {
                    Write-Output "${name}: aliased to $($cmd.Definition)"
                }
                'Function' {
                    $file = $null
                    try {
                        if ($cmd.ScriptBlock -and $cmd.ScriptBlock.File) {
                            $file = $cmd.ScriptBlock.File
                        }
                    } catch { }
                    if ($file) { Write-Output $file }
                    else { Write-Output "${name}: shell function" }
                }
                'Cmdlet' {
                    Write-Output "$($cmd.ModuleName)\$($cmd.Name)"
                }
                default {
                    if ($cmd.Source) { Write-Output $cmd.Source }
                    else { Write-Output "$($cmd.CommandType): ${name}" }
                }
            }
            if (-not $all) { break }
        }

        if (-not $found) {
            Write-Error "which: no ${name} in ($env:PATH)"
            $hadError = $true
        }
    }

    if ($hadError) { Set-UnixExitCode -Code 1 }
}
