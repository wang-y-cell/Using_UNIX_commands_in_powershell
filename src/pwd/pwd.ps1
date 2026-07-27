Remove-Item alias:pwd -ErrorAction SilentlyContinue
function pwd {
    param([switch]$P)
    $path = (Get-Location).Path
    if ($P) {
        try { return (Get-Item -LiteralPath $path).FullName }
        catch { return $path }
    }
    return $path
}
