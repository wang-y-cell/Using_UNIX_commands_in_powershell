# 统一控制台 / 管道为 UTF-8，避免中文乱码（仓库脚本按 UTF-8 保存）
# 由 load.ps1 / build.ps1 写入的 $PROFILE 块最先加载
try {
    chcp 65001 | Out-Null
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    [Console]::InputEncoding  = $utf8
    [Console]::OutputEncoding = $utf8
    $OutputEncoding = $utf8
} catch {
    # 非控制台宿主（无控制台句柄）时忽略
}
