# tree（简单函数 + $args）
# 支持：tree [-a] [-d] [-L N] [DIR...]
# 例：tree
#     tree -L 2 .\src
#     tree -d .\src
function tree {
    $argv = @($args)
    $showAll = $false
    $dirsOnly = $false
    $maxDepth = [int]::MaxValue
    $paths = [System.Collections.Generic.List[string]]::new()
    $i = 0

    while ($i -lt $argv.Count) {
        $tok = [string]$argv[$i]
        if ($tok -match '^-L(\d+)$') {
            $maxDepth = [int]$Matches[1]
            $i++
            continue
        }
        if ($tok -eq '-L') {
            if ($i + 1 -ge $argv.Count) {
                Write-Error 'tree: option requires an argument -- L'
                return
            }
            $numTok = [string]$argv[$i + 1]
            if ($numTok -notmatch '^\d+$') {
                Write-Error "tree: invalid level: '${numTok}'"
                return
            }
            $maxDepth = [int]$numTok
            $i += 2
            continue
        }
        if ($tok -match '^-([a-zA-Z]+)$') {
            foreach ($ch in $Matches[1].ToLowerInvariant().ToCharArray()) {
                switch ([string]$ch) {
                    'a' { $showAll = $true }
                    'd' { $dirsOnly = $true }
                    default {
                        Write-Error "tree: invalid option -- '${ch}'"
                        return
                    }
                }
            }
            $i++
            continue
        }
        $paths.Add($tok)
        $i++
    }

    if ($paths.Count -eq 0) { $paths.Add('.') }

    $useColor = $true
    try {
        if ([Console]::IsOutputRedirected) { $useColor = $false }
    } catch { }

    $stats = @{ Dirs = 0; Files = 0 }

    $writeName = {
        param($Item, [string]$Prefix)
        Write-Host $Prefix -NoNewline
        if ($useColor) {
            $rgb = Get-ItemColor $Item
            Write-RGB -Text $Item.Name -R $rgb[0] -G $rgb[1] -B $rgb[2]
        } else {
            Write-Host $Item.Name
        }
    }

    $walk = $null
    $walk = {
        param([string]$DirPath, [string]$Prefix, [int]$Depth)

        if ($Depth -ge $maxDepth) { return }

        try {
            $items = @(Get-ChildItem -LiteralPath $DirPath -Force -ErrorAction Stop)
        } catch {
            Write-Error "tree: ${DirPath}: $($_.Exception.Message)"
            return
        }

        if (-not $showAll) {
            $items = @($items | Where-Object { -not $_.Name.StartsWith('.') })
        }
        if ($dirsOnly) {
            $items = @($items | Where-Object { $_.PSIsContainer })
        }
        $items = @($items | Sort-Object { -not $_.PSIsContainer }, Name)

        for ($idx = 0; $idx -lt $items.Count; $idx++) {
            $item = $items[$idx]
            $isLast = ($idx -eq $items.Count - 1)
            $branch = if ($isLast) { '`-- ' } else { '|-- ' }
            & $writeName $item ($Prefix + $branch)

            if ($item.PSIsContainer) {
                $stats.Dirs++
                $childPrefix = $Prefix + $(if ($isLast) { '    ' } else { '|   ' })
                & $walk $item.FullName $childPrefix ($Depth + 1)
            } else {
                $stats.Files++
            }
        }
    }

    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) {
            Write-Error "tree: ${path}: No such file or directory"
            continue
        }
        $item = Get-Item -LiteralPath $path -Force
        if (-not $item.PSIsContainer) {
            Write-Error "tree: ${path}: Not a directory"
            continue
        }

        if ($useColor) {
            $rgb = Get-ItemColor $item
            Write-RGB -Text $item.FullName -R $rgb[0] -G $rgb[1] -B $rgb[2]
        } else {
            Write-Host $item.FullName
        }

        $stats.Dirs = 0
        $stats.Files = 0
        & $walk $item.FullName '' 0

        $dirLabel = if ($stats.Dirs -eq 1) { 'directory' } else { 'directories' }
        $fileLabel = if ($stats.Files -eq 1) { 'file' } else { 'files' }
        Write-Host ''
        Write-Host "$($stats.Dirs) $dirLabel, $($stats.Files) $fileLabel"
    }
}
