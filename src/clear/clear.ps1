# clear
# clear the screen
Remove-Item -Force alias:clear -ErrorAction SilentlyContinue
function clear {
    Clear-Host
}
