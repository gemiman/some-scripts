#!/bin/bash

# Arch Linux 系统更新与清理脚本

echo "=========================================="
echo "  Arch Linux 系统更新与清理"
echo "=========================================="
echo ""

# 更新系统
echo ">>> 正在更新系统..."
sudo pacman -Syu

echo ""
echo ">>> 清理未使用的包..."
sudo pacman -Rns $(pacman -Qdtq) 2>/dev/null || echo "没有需要清理的孤立包"

echo ""
echo ">>> 清理 pacman 缓存（保留最近2个版本）..."
sudo paccache -r

echo ""
echo ">>> 清理旧的内核等已卸载包残留..."
sudo pacman -Sc

echo ""
echo ">>> 清理日志文件（限制50MB）..."
sudo journalctl --vacuum-size=50M

# yay/paru 更新
if command -v yay &>/dev/null; then
    echo ""
    echo ">>> 正在通过 yay 更新 AUR 包..."
    yay -Syu
elif command -v paru &>/dev/null; then
    echo ""
    echo ">>> 正在通过 paru 更新 AUR 包..."
    paru -Syu
fi

# flatpak 更新
if command -v flatpak &>/dev/null; then
    echo ""
    echo ">>> 正在更新 flatpak 应用..."
    flatpak update -y

    echo ""
    echo ">>> 正在清理 flatpak 未使用的运行时..."
    flatpak remove --unused -y
fi

echo ""
echo "=========================================="
echo "  清理完成！"
echo "=========================================="
