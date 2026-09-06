# 从标准输入逐行读取（无文件参数时模拟 GNU 读 stdin；Windows 下 EOF 为 Ctrl+Z）
function Read-UnixStdinLines {
    $inputStream = [Console]::OpenStandardInput()
    $reader = [System.IO.StreamReader]::new(
        $inputStream,
        [Console]::InputEncoding,
        $true,
        1024,
        $true
    )
    try {
        while ($null -ne ($line = $reader.ReadLine())) {
            Write-Output $line
        }
    }
    finally {
        $reader.Dispose()
    }
}
