# sort锛堢畝鍗曞嚱鏁?+ $args锛?
# 鏀寔锛歴ort [-rnu] [FILE...]銆佺閬撹緭鍏?
# 渚嬶細sort a.txt
#     Get-Content a.txt | sort -r
#     ls | sort -u
Remove-Item -Force alias:sort -ErrorAction SilentlyContinue
function sort {
    begin {
        $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
        $files = @(Get-UnixPathArgs -Arguments $args)

        $reverse = $flags -contains 'r'
        $numeric = $flags -contains 'n'
        $unique = $flags -contains 'u'
        $fromPipeline = $MyInvocation.ExpectingInput
        $lines = [System.Collections.Generic.List[string]]::new()
    }

    process {
        if (-not $fromPipeline) { return }
        $line = if ($_ -is [string]) { $_ } else { "$_" }
        $lines.Add($line)
    }

    end {
        if (-not $fromPipeline) {
            if ($files.Count -eq 0) {
                Write-Error 'sort: missing file operand'
                return
            }
            foreach ($file in $files) {
                if (-not (Test-Path -LiteralPath $file)) {
                    Write-Error "sort: open failed: ${file}: No such file or directory"
                    continue
                }
                $item = Get-Item -LiteralPath $file -Force
                if ($item.PSIsContainer) {
                    Write-Error "sort: read failed: ${file}: Is a directory"
                    continue
                }
                try {
                    foreach ($line in [System.IO.File]::ReadLines($item.FullName)) {
                        $lines.Add($line)
                    }
                } catch {
                    Write-Error "sort: ${file}: $($_.Exception.Message)"
                }
            }
        }

        if ($lines.Count -eq 0) { return }

        $sorted = if ($numeric) {
            $lines | Sort-Object {
                $t = "$_"
                if ($t -match '^\s*([+-]?\d+(\.\d+)?)') { [double]$Matches[1] } else { [double]::NaN }
            }, { "$_" }
        } else {
            $lines | Sort-Object { "$_" }
        }

        if ($reverse) {
            $sorted = @($sorted)
            [Array]::Reverse($sorted)
        }

        if ($unique) {
            $prev = $null
            $hasPrev = $false
            foreach ($line in $sorted) {
                if ($hasPrev -and $line -ceq $prev) { continue }
                Write-Output $line
                $prev = $line
                $hasPrev = $true
            }
        } else {
            foreach ($line in $sorted) {
                Write-Output $line
            }
        }
    }
}
