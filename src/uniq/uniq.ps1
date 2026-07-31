# uniq（简单函数 + $args）
# 支持：uniq [-cid] [FILE...]、管道输入；仅去除相邻重复行
# 例：sort a.txt | uniq
#     uniq -c a.txt
#     Get-Content a.txt | uniq -i
function uniq {
    begin {
        $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
        $files = @(Get-UnixPathArgs -Arguments $args)

        $showCount = $flags -contains 'c'
        $ignoreCase = $flags -contains 'i'
        $onlyDuplicate = $flags -contains 'd'
        $fromPipeline = $MyInvocation.ExpectingInput

        $state = @{
            HasPrev = $false
            Prev    = $null
            Count   = 0
        }

        $sameAs = {
            param([string]$A, [string]$B)
            if ($ignoreCase) { return $A.Equals($B, [System.StringComparison]::OrdinalIgnoreCase) }
            return $A -ceq $B
        }

        $emitRun = {
            param([string]$Line, [int]$Count)
            if ($onlyDuplicate -and $Count -lt 2) { return }
            if ($showCount) {
                Write-Output ("{0,7} {1}" -f $Count, $Line)
            } else {
                Write-Output $Line
            }
        }

        $feed = {
            param([string]$Line)
            if (-not $state.HasPrev) {
                $state.Prev = $Line
                $state.Count = 1
                $state.HasPrev = $true
                return
            }
            if (& $sameAs $Line $state.Prev) {
                $state.Count++
                return
            }
            & $emitRun $state.Prev $state.Count
            $state.Prev = $Line
            $state.Count = 1
        }
    }

    process {
        if (-not $fromPipeline) { return }
        $line = if ($_ -is [string]) { $_ } else { "$_" }
        & $feed $line
    }

    end {
        if ($fromPipeline) {
            if ($state.HasPrev) { & $emitRun $state.Prev $state.Count }
            return
        }

        if ($files.Count -eq 0) {
            Write-Error 'uniq: missing file operand'
            return
        }

        foreach ($file in $files) {
            if (-not (Test-Path -LiteralPath $file)) {
                Write-Error "uniq: ${file}: No such file or directory"
                continue
            }
            $item = Get-Item -LiteralPath $file -Force
            if ($item.PSIsContainer) {
                Write-Error "uniq: ${file}: Is a directory"
                continue
            }

            $state.HasPrev = $false
            $state.Prev = $null
            $state.Count = 0
            try {
                foreach ($line in [System.IO.File]::ReadLines($item.FullName)) {
                    & $feed $line
                }
                if ($state.HasPrev) { & $emitRun $state.Prev $state.Count }
            } catch {
                Write-Error "uniq: ${file}: $($_.Exception.Message)"
            }
        }
    }
}
