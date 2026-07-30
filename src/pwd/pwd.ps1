Remove-Item alias:pwd -ErrorAction SilentlyContinue
function pwd {
    $flags = @(Get-UnixShortFlagChars -Arguments $args | ForEach-Object { $_.ToLowerInvariant() })
    $path = (Get-Location).Path
    if ($flags -contains 'p') {
        try { return (Get-Item -LiteralPath $path).FullName }
        catch { return $path }
    }
    return $path
}
