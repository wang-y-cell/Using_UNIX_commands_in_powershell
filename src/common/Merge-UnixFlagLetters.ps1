# 合并 Linux 风格短选项（基于 Get-UnixShortFlagChars / Get-UnixPathArgs）
function Merge-UnixFlagLetters {
    param(
        [string]$Seed = '',
        [string[]]$ExtraSwitches,
        [object[]]$RemainingArguments,
        [string]$AllowedPattern = '[a-zA-Z]'
    )

    $argList = [System.Collections.Generic.List[object]]::new()
    if ($Seed) { $argList.Add("-$Seed") }
    foreach ($sw in @($ExtraSwitches)) {
        if ($sw) { $argList.Add("-$sw") }
    }
    foreach ($arg in @($RemainingArguments)) {
        if ($null -ne $arg) { $argList.Add($arg) }
    }

    $allChars = @(Get-UnixShortFlagChars -Arguments $argList.ToArray())
    $allowedChars = [System.Collections.Generic.List[string]]::new()
    foreach ($ch in $allChars) {
        if ($ch -match "^$AllowedPattern$") {
            $allowedChars.Add($ch)
        }
    }

    return [pscustomobject]@{
        Flags = ($allowedChars -join '')
        Paths = @(Get-UnixPathArgs -Arguments $argList.ToArray())
    }
}
