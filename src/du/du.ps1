# du（简单函数 + $args）
# 支持：du [-ahs] [PATH...]；默认递归列出各目录（对齐 GNU du）
function du {
    $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
    $paths = @(Get-UnixPathArgs -Arguments $args)
    $paths = @(Expand-UnixGlob -Path $paths)

    $human = $flags -contains 'h'
    $summarize = $flags -contains 's'
    $all = $flags -contains 'a'
    if ($paths.Count -eq 0) { $paths = @('.') }

    $sizeWidth = if ($human) { 8 } else { 12 }
    $state = @{
        HadError = $false
        Cache    = @{}
        Human    = $human
        All      = $all
        SizeWidth = $sizeWidth
    }
    Set-UnixExitCode -Code 0

    # 用 hashtable 挂接递归，避免 GetNewClosure 捕获到未赋值的脚本块
    $state.GetSize = {
        param($Item)
        $key = $Item.FullName
        if ($state.Cache.ContainsKey($key)) { return [int64]$state.Cache[$key] }

        if ($Item.PSIsContainer) {
            $sum = [int64]0
            Get-ChildItem -LiteralPath $Item.FullName -Force -ErrorAction SilentlyContinue | ForEach-Object {
                $sum += [int64](& $state.GetSize $_)
            }
            $state.Cache[$key] = $sum
            return $sum
        }
        $len = [int64]$Item.Length
        $state.Cache[$key] = $len
        return $len
    }.GetNewClosure()

    $state.Emit = {
        param([int64]$Bytes, [string]$Label)
        $sizeText = Format-FileSize -Bytes $Bytes -HumanReadable:$($state.Human)
        Write-Output ("{0}  {1}" -f $sizeText.PadLeft($state.SizeWidth), $Label)
    }.GetNewClosure()

    $state.Walk = {
        param($DirItem, [string]$Label)
        try {
            $children = @(Get-ChildItem -LiteralPath $DirItem.FullName -Force -ErrorAction Stop)
        } catch {
            Write-Error "du: cannot read directory '${Label}': $($_.Exception.Message)"
            $state.HadError = $true
            return (& $state.GetSize $DirItem)
        }

        foreach ($child in ($children | Sort-Object Name)) {
            $childLabel = Join-Path $Label $child.Name
            if ($child.PSIsContainer) {
                $null = & $state.Walk $child $childLabel
            } elseif ($state.All) {
                & $state.Emit (& $state.GetSize $child) $childLabel
            }
        }

        $bytes = & $state.GetSize $DirItem
        & $state.Emit $bytes $Label
        return $bytes
    }.GetNewClosure()

    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) {
            Write-Error "du: cannot access '${path}': No such file or directory"
            $state.HadError = $true
            continue
        }
        $root = Get-Item -LiteralPath $path -Force

        if ($summarize -or -not $root.PSIsContainer) {
            & $state.Emit (& $state.GetSize $root) $path
            continue
        }

        $null = & $state.Walk $root $path
    }

    if ($state.HadError) { Set-UnixExitCode -Code 1 }
}
