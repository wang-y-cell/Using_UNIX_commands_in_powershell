# 合并 Linux 风格短选项（独立开关 + -rf 等组合 + 位置参数中的 -xxx）
function Merge-UnixFlagLetters {
    param(
        [string]$Seed = '',
        [string[]]$ExtraSwitches,
        [object[]]$RemainingArguments,
        [string]$AllowedPattern = '[a-zA-Z]'
    )

    $flagText = $Seed
    foreach ($sw in @($ExtraSwitches)) {
        if ($sw) { $flagText += $sw }
    }

    $pathArgs = [System.Collections.Generic.List[string]]::new()
    foreach ($arg in @($RemainingArguments)) {
        if ($null -eq $arg) { continue }
        $text = [string]$arg
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        if ($text -match "^-$AllowedPattern+$") {
            $flagText += $text.TrimStart('-')
            continue
        }
        $pathArgs.Add($text)
    }

    return [pscustomobject]@{
        Flags = $flagText
        Paths = $pathArgs.ToArray()
    }
}
