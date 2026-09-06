# cat + $args
# 支持：cat [-nb] [FILE...]；无文件时读 stdin；- 表示 stdin
Remove-Item -Force alias:cat -ErrorAction SilentlyContinue
function cat {
    begin {
        $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
        $files = @(Get-UnixPathArgs -Arguments $args)
        $files = @(Expand-UnixGlob -Path $files)

        $numberAll = $flags -contains 'n'
        $numberNonBlank = $flags -contains 'b'
        if ($numberNonBlank) { $numberAll = $false }

        $fromPipeline = $MyInvocation.ExpectingInput
        $hadError = $false
        Set-UnixExitCode -Code 0
        $state = @{
            LineNo     = 0
            NonBlankNo = 0
        }

        $emit = {
            param([string]$Line)
            if ($numberNonBlank) {
                if ($Line -match '\S') {
                    $state.NonBlankNo++
                    Write-Output ("{0,6}`t{1}" -f $state.NonBlankNo, $Line)
                }
                else {
                    Write-Output $Line
                }
                return
            }
            if ($numberAll) {
                $state.LineNo++
                Write-Output ("{0,6}`t{1}" -f $state.LineNo, $Line)
                return
            }
            Write-Output $Line
        }.GetNewClosure()
    }

    process {
        if (-not $fromPipeline) { return }
        $line = if ($_ -is [string]) { $_ } else { "$_" }
        & $emit $line
    }

    end {
        if ($fromPipeline) {
            if ($hadError) { Set-UnixExitCode -Code 1 }
            return
        }

        if ($files.Count -eq 0) {
            foreach ($line in @(Read-UnixStdinLines)) {
                & $emit $line
            }
            return
        }

        foreach ($file in $files) {
            if ($file -eq '-') {
                foreach ($line in @(Read-UnixStdinLines)) {
                    & $emit $line
                }
                continue
            }
            if (-not (Test-Path -LiteralPath $file)) {
                Write-Error "cat: ${file}: No such file or directory"
                $hadError = $true
                continue
            }
            $item = Get-Item -LiteralPath $file -Force
            if ($item.PSIsContainer) {
                Write-Error "cat: ${file}: Is a directory"
                $hadError = $true
                continue
            }

            try {
                foreach ($line in [System.IO.File]::ReadLines($item.FullName)) {
                    & $emit $line
                }
            }
            catch {
                Write-Error "cat: ${file}: $($_.Exception.Message)"
                $hadError = $true
            }
        }

        if ($hadError) { Set-UnixExitCode -Code 1 }
    }
}
