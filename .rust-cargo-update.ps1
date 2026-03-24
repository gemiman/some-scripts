# 强制设置编码（确保中文不乱码）
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "`n[>>>] 正在初始化 Rust 全局更新程序..." -ForegroundColor Cyan

# --- 第一部分：更新 Rust 工具链 ---
Write-Host "[1/2] 正在同步 Rust 官方工具链..." -ForegroundColor Yellow
rustup update

# --- 第二部分：更新 Cargo 二进制组件 ---
Write-Host "`n[2/2] 正在检查并更新已安装的 Cargo 组件..." -ForegroundColor Yellow

# 检查插件
if (-not (Get-Command cargo-install-update -ErrorAction SilentlyContinue)) {
    Write-Host "提示：未发现 cargo-update，正在安装..." -ForegroundColor DarkCyan
    cargo install cargo-update
}

# 修复后的核心命令：
# 使用 --all 替代简写的 -a，并移除可能引起歧义的参数
# 如果你依然遇到 filter 错误，请尝试使用下面这一行：
cargo install-update --all

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "  所有任务已完成！" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

Read-Host "按下回车键退出..."