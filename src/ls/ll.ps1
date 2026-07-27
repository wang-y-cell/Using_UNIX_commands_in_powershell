# ll：固定等价于 ls -alh
function ll {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$RemainingArguments
    )
    if ($RemainingArguments -and $RemainingArguments.Count -gt 0) {
        ls-horizontal -alh @RemainingArguments
    } else {
        ls-horizontal -alh
    }
}
