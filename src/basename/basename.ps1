# basename（简单函数 + $args）
# 支持：basename NAME [SUFFIX]
#       basename -a NAME...
#       basename -s SUFFIX NAME...
# 例：basename C:\foo\bar.txt
#     basename C:\foo\bar.txt .txt
#     basename -a a.txt b.txt
#     basename -s .ps1 .\src\cat\cat.ps1
function Get-BasenameResult {
    param(
        [string]$Name,
        [string]$Suffix
    )

    if ([string]::IsNullOrEmpty($Name)) { return '' }

    $trimmed = $Name.TrimEnd('\', '/')
    if ([string]::IsNullOrEmpty($trimmed)) {
        if ($Name -match '^[A-Za-z]:\\?$') {
            return ($Name.Substring(0, 2).TrimEnd('\') + '\')
        }
        return $Name
    }

    $base = [System.IO.Path]::GetFileName($trimmed)
    if ([string]::IsNullOrEmpty($base)) { $base = $trimmed }

    if ($Suffix -and $base.Length -gt $Suffix.Length -and $base.EndsWith($Suffix, [System.StringComparison]::Ordinal)) {
        $base = $base.Substring(0, $base.Length - $Suffix.Length)
    }
    return $base
}

function basename {
    $argv = @($args)
    if ($argv.Count -eq 0) {
        Write-Error 'basename: missing operand'
        return
    }

    $all = $false
    $suffix = $null
    $names = [System.Collections.Generic.List[string]]::new()
    $i = 0

    while ($i -lt $argv.Count) {
        $tok = [string]$argv[$i]
        if ($tok -eq '-a') {
            $all = $true
            $i++
            continue
        }
        if ($tok -eq '-s') {
            if ($i + 1 -ge $argv.Count) {
                Write-Error 'basename: option requires an argument -- s'
                return
            }
            $suffix = [string]$argv[$i + 1]
            $all = $true
            $i += 2
            continue
        }
        if ($tok -match '^-s(.+)$') {
            $suffix = $Matches[1]
            $all = $true
            $i++
            continue
        }
        if ($tok -match '^-([a-zA-Z]+)$') {
            Write-Error "basename: invalid option -- '$($Matches[1][0])'"
            return
        }
        $names.Add($tok)
        $i++
    }

    if ($names.Count -eq 0) {
        Write-Error 'basename: missing operand'
        return
    }

    if (-not $all) {
        if ($names.Count -gt 2) {
            Write-Error 'basename: extra operand (use -a for multiple names)'
            return
        }
        $name = $names[0]
        $suf = if ($names.Count -eq 2) { $names[1] } else { $null }
        foreach ($n in @(Expand-UnixGlob -Path $name)) {
            Write-Output (Get-BasenameResult -Name $n -Suffix $suf)
        }
        return
    }

    foreach ($name in @(Expand-UnixGlob -Path @($names))) {
        Write-Output (Get-BasenameResult -Name $name -Suffix $suffix)
    }
}
