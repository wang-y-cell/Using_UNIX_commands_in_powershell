function Convert-FindSizeSpec {
    param([Parameter(Mandatory = $true)][string]$Spec)

    if ($Spec -notmatch '^([+-]?)(\d+)([bcCkKmMgG]?)$') {
        throw "无效的 -size 参数: $Spec  （示例: +100M, -10k, 512）"
    }

    $op = $Matches[1]
    $num = [long]$Matches[2]
    $unit = $Matches[3]

    $bytes = switch -CaseSensitive ($unit) {
        'b' { $num }
        'c' { $num }
        'C' { $num }
        'k' { $num * 1KB }
        'K' { $num * 1KB }
        'm' { $num * 1MB }
        'M' { $num * 1MB }
        'g' { $num * 1GB }
        'G' { $num * 1GB }
        default { $num * 512 } # 与 GNU find 默认 512 字节块一致
    }

    return [pscustomobject]@{ Op = $op; Bytes = $bytes }
}

function Convert-FindTimeSpec {
    param([Parameter(Mandatory = $true)][string]$Spec)

    if ($Spec -notmatch '^([+-]?)(\d+)$') {
        throw "无效的时间参数: $Spec  （示例: -1, +30, 7）"
    }

    return [pscustomobject]@{ Op = $Matches[1]; N = [double]$Matches[2] }
}

function Test-FindNumericFilter {
    param(
        [double]$Value,
        [string]$Op,
        [double]$N
    )

    switch ($Op) {
        '+' { return $Value -gt $N }
        '-' { return $Value -lt $N }
        default { return [Math]::Floor($Value) -eq $N }
    }
}

function Test-FindIsSymlink {
    param($Item)
    if ($null -ne $Item.LinkType -and $Item.LinkType -eq 'SymbolicLink') {
        return $true
    }
    # 兼容部分环境未填充 LinkType 的情况
    try {
        return [bool]($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and -not $Item.PSIsContainer
    } catch {
        return $false
    }
}