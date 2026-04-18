#!/bin/bash

# 更新软件源
echo "更新软件源..."
sudo apt update -y

# 升级所有已安装的软件包
echo "升级已安装的软件包..."
sudo apt upgrade -y

# 升级可用的分发版本（可选）
echo "升级到新的发行版..."
sudo apt dist-upgrade -y

# 升级rust
rustup update

# 升级cargo安装的包
echo "升级Cargo安装的包..."
cargo install cargo-update
cargo install-update -a

# 删除不再需要的包和依赖
echo "清理不再需要的包..."
sudo apt autoremove -y

# 清理本地的缓存包
echo "清理本地缓存..."
sudo apt clean

echo "更新完成！"