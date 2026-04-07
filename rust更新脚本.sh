#!/bin/bash

# Rust 更新脚本

echo "=========================================="
echo "  Rust 工具链更新"
echo "=========================================="
echo ""

# 更新 rustup
echo ">>> 正在更新 rustup..."
rustup update

echo ""
echo ">>> 正在更新所有 cargo install 安装的包..."
cargo install-update -a

echo ""
echo "=========================================="
echo "  更新完成！"
echo "=========================================="
