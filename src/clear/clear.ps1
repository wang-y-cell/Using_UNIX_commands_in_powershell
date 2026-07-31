# clear锛堢畝鍗曞嚱鏁帮級
# 娓呭睆锛岀瓑浠蜂簬 Clear-Host
# 渚嬶細clear
Remove-Item -Force alias:clear -ErrorAction SilentlyContinue
function clear {
    Clear-Host
}
