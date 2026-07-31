# du（简单函数 + $args）
# 支持：du [-ahs] [PATH...]
# 例：du -sh .
#     du -h .\src
#     du -a .\src\common
# 每扫完一项立即输出一行（固定宽度右对齐），避免长时间无反馈
function du {
    $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
    $paths = @(Get-UnixPathArgs -Arguments $args)

    $human = $flags -contains 'h'
    $summarize = $flags -contains 's'
    $all = $flags -contains 'a'
    if ($paths.Count -eq 0) { $paths = @('.') }

    # 人类可读较短，字节数最长约 15 位；固定宽度便于边扫边打仍对齐
    $sizeWidth = if ($human) { 8 } else { 12 }

    $getSize = {
        param($Item)
        if ($Item.PSIsContainer) {
            $sum = [int64]0
            try {
                Get-ChildItem -LiteralPath $Item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue |
                    ForEach-Object { $sum += $_.Length }
            } catch { }
            return $sum
        }
        return [int64]$Item.Length
    }

    $emit = {
        param([int64]$Bytes, [string]$Label)
        $sizeText = Format-FileSize -Bytes $Bytes -HumanReadable:$human
        Write-Output ("{0}  {1}" -f $sizeText.PadLeft($sizeWidth), $Label)
    }

    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) {
            Write-Error "du: cannot access '${path}': No such file or directory"
            continue
        }
        $root = Get-Item -LiteralPath $path -Force

        if ($summarize -or -not $root.PSIsContainer) {
            & $emit (& $getSize $root) $path
            continue
        }

        try {
            $children = @(Get-ChildItem -LiteralPath $root.FullName -Force -ErrorAction Stop)
        } catch {
            Write-Error "du: cannot read directory '${path}': $($_.Exception.Message)"
            continue
        }

        foreach ($child in ($children | Sort-Object Name)) {
            if (-not $all -and -not $child.PSIsContainer) { continue }
            $label = Join-Path $path $child.Name
            & $emit (& $getSize $child) $label
        }
        & $emit (& $getSize $root) $path
    }
}
