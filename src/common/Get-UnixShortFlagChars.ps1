# 从命令参数数组中解析 Linux 风格短选项，返回单字符数组
# 例：-al、'-lh'、混合路径 → @('a','l','h')；忽略非 -xxx 的路径参数；不处理 --long
function Get-UnixShortFlagChars {
    param(
        [Parameter(Mandatory = $false)]
        [object[]]$Arguments
    )

    $chars = [System.Collections.Generic.List[string]]::new()

    foreach ($arg in @($Arguments)) {
        if ($null -eq $arg) { continue }
        $text = [string]$arg
        if ([string]::IsNullOrWhiteSpace($text)) { continue }

        # 仅匹配短选项：-a / -al / -alh（单个 '-' + 字母）
        if ($text -match '^-([a-zA-Z]+)$') {
            foreach ($ch in $Matches[1].ToCharArray()) {
                $chars.Add([string]$ch)
            }
        }
    }

    return [string[]]$chars.ToArray()
}

# 从命令参数数组中取出非短选项参数（路径等）
function Get-UnixPathArgs {
    param(
        [Parameter(Mandatory = $false)]
        [object[]]$Arguments
    )

    $paths = [System.Collections.Generic.List[string]]::new()

    foreach ($arg in @($Arguments)) {
        if ($null -eq $arg) { continue }
        $text = [string]$arg
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        if ($text -match '^-([a-zA-Z]+)$') { continue }
        $paths.Add($text)
    }

    return [string[]]$paths.ToArray()
}

# 将已绑定的 [switch] 与 RemainingArguments 拼成可解析的参数数组
# 例：-r -f 与 RemainingArguments 中的 -rf、路径 → @('-r','-f','-rf','.\dir')
function Get-UnixArgumentList {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$BoundParameters,

        [object[]]$RemainingArguments,

        [string[]]$ExcludeKeys = @('RemainingArguments')
    )

    $list = [System.Collections.Generic.List[object]]::new()

    foreach ($key in @($BoundParameters.Keys)) {
        if ($ExcludeKeys -contains $key) { continue }
        $val = $BoundParameters[$key]
        # 已出现的 switch 记为 -Name（如 al → -al）
        if ($val -is [bool] -or $val -is [System.Management.Automation.SwitchParameter]) {
            if ($val) { $list.Add("-$key") }
            continue
        }
    }

    foreach ($arg in @($RemainingArguments)) {
        if ($null -eq $arg) { continue }
        $list.Add($arg)
    }

    return [object[]]$list.ToArray()
}
