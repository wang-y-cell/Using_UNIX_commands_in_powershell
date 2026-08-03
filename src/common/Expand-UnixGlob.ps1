# 判断路径是否含通配符（* ? [...]；** 由 * 覆盖）
function Test-UnixGlobPattern {
    param(
        [Parameter(Mandatory = $false)]
        [string]$Pattern
    )

    if ([string]::IsNullOrEmpty($Pattern)) { return $false }

    $chars = $Pattern.ToCharArray()
    for ($i = 0; $i -lt $chars.Length; $i++) {
        $ch = $chars[$i]
        if ($ch -eq '*' -or $ch -eq '?') { return $true }
        if ($ch -eq '[') {
            for ($j = $i + 1; $j -lt $chars.Length; $j++) {
                if ($chars[$j] -eq ']') { return $true }
            }
        }
    }
    return $false
}

# 展开路径通配符：无通配原样返回；有通配则匹配；无匹配静默（贡献 0 条）
# 支持 * ? []；完整路径段 ** 匹配零或多层目录
function Expand-UnixGlob {
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$Path
    )

    $results = [System.Collections.Generic.List[string]]::new()
    foreach ($p in @($Path)) {
        if ($null -eq $p) { continue }
        $text = [string]$p
        if ([string]::IsNullOrWhiteSpace($text)) { continue }

        if (-not (Test-UnixGlobPattern -Pattern $text)) {
            $results.Add($text)
            continue
        }

        # Expand-UnixGlobOne 通过管道输出匹配项；无匹配则无输出
        Expand-UnixGlobOne -Pattern $text | ForEach-Object {
            if (-not [string]::IsNullOrEmpty($_)) {
                $results.Add([string]$_)
            }
        }
    }

    foreach ($r in $results) {
        Write-Output $r
    }
}

function Expand-UnixGlobOne {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $sep = [System.IO.Path]::DirectorySeparatorChar
    $norm = $Pattern -replace '[\\/]', [string]$sep

    $currents = [System.Collections.Generic.List[string]]::new()
    $segments = [System.Collections.Generic.List[string]]::new()

    if ([System.IO.Path]::IsPathRooted($norm)) {
        $root = [System.IO.Path]::GetPathRoot($norm)
        if ([string]::IsNullOrEmpty($root)) { return }
        $rootItem = Get-Item -LiteralPath $root -Force -ErrorAction SilentlyContinue
        if (-not $rootItem) { return }
        $currents.Add($rootItem.FullName)

        $rest = $norm.Substring($root.Length).TrimStart($sep)
        if (-not [string]::IsNullOrEmpty($rest)) {
            foreach ($s in $rest.Split(@($sep), [System.StringSplitOptions]::RemoveEmptyEntries)) {
                $segments.Add($s)
            }
        }
    }
    else {
        $currents.Add((Get-Location).Path)
        foreach ($s in $norm.Split(@($sep), [System.StringSplitOptions]::RemoveEmptyEntries)) {
            $segments.Add($s)
        }
    }

    if ($segments.Count -eq 0) {
        Write-Output $currents[0]
        return
    }

    foreach ($seg in $segments) {
        $next = [System.Collections.Generic.List[string]]::new()

        if ($seg -eq '**') {
            foreach ($dir in $currents) {
                $item = Get-Item -LiteralPath $dir -Force -ErrorAction SilentlyContinue
                if (-not $item -or -not $item.PSIsContainer) { continue }
                $next.Add($item.FullName)
                Get-ChildItem -LiteralPath $item.FullName -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                    ForEach-Object { $next.Add($_.FullName) }
            }
        }
        elseif (Test-UnixGlobPattern -Pattern $seg) {
            $wc = [System.Management.Automation.WildcardPattern]::new(
                $seg,
                [System.Management.Automation.WildcardOptions]::IgnoreCase
            )
            foreach ($dir in $currents) {
                $dirItem = Get-Item -LiteralPath $dir -Force -ErrorAction SilentlyContinue
                if (-not $dirItem -or -not $dirItem.PSIsContainer) { continue }
                Get-ChildItem -LiteralPath $dirItem.FullName -Force -ErrorAction SilentlyContinue |
                    Where-Object { $wc.IsMatch($_.Name) } |
                    ForEach-Object { $next.Add($_.FullName) }
            }
        }
        else {
            foreach ($dir in $currents) {
                $candidate = Join-Path $dir $seg
                $item = Get-Item -LiteralPath $candidate -Force -ErrorAction SilentlyContinue
                if ($item) { $next.Add($item.FullName) }
            }
        }

        $currents = $next
        if ($currents.Count -eq 0) { return }
    }

    $seen = @{}
    foreach ($c in $currents) {
        if (-not $seen.ContainsKey($c)) {
            $seen[$c] = $true
            Write-Output $c
        }
    }
}
