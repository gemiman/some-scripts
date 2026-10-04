#!/usr/bin/env bash
# =============================================================================
#  update-ynote.sh —— 有道云笔记 安装 / 升级 / 卸载（Fedora）
#
#  背景：有道云笔记官方只发布 .deb（没有 RPM），Fedora 上只能拆包安装。
#        手动装的东西 dnf 管不到，所以用本脚本负责安装与升级。
#
#  用法：
#      ./update-ynote.sh              安装或升级（已是最新则跳过下载）
#      ./update-ynote.sh --check      只检查有没有新版本，不改动系统
#      ./update-ynote.sh --force      忽略版本比对，强制重新安装
#      ./update-ynote.sh --uninstall  卸载
#
#  设计说明：
#      · deb 是 ar 归档，成员顺序为 debian-binary → control.tar.gz → data.tar.xz，
#        控制信息在最前面 —— 所以「查版本」只需下载前 256 KB，不必拉完整的 161 MB。
#      · 用户数据（笔记、登录状态）在 ~/.config/ 下，不在 /opt，
#        故覆盖或删除 /opt 下的程序本体不影响数据。
# =============================================================================

set -euo pipefail

DEB_URL="https://artifact.lx.netease.com/download/ynote-electron/%E6%9C%89%E9%81%93%E4%BA%91%E7%AC%94%E8%AE%B0-web.deb"
APP_DIR="/opt/有道云笔记"
BIN_NAME="ynote-desktop"
DESKTOP_FILE="ynote-desktop.desktop"
VER_FILE="$APP_DIR/.installed-version"
HEAD_BYTES=262143          # 前 256 KB 足以覆盖 control.tar.gz

c_g=$'\033[32m'; c_y=$'\033[33m'; c_r=$'\033[31m'; c_b=$'\033[34m'; c_0=$'\033[0m'
info() { printf '%s[·]%s %s\n' "$c_b" "$c_0" "$*"; }
ok()   { printf '%s[✓]%s %s\n' "$c_g" "$c_0" "$*"; }
warn() { printf '%s[!]%s %s\n' "$c_y" "$c_0" "$*"; }
err()  { printf '%s[✗]%s %s\n' "$c_r" "$c_0" "$*"; }

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

MODE="install"; FORCE=0
case "${1:-}" in
  --check)     MODE="check" ;;
  --force)     FORCE=1 ;;
  --uninstall) MODE="uninstall" ;;
  -h|--help)   sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "")          ;;
  *)           err "未知参数：$1（用 --help 看用法）"; exit 2 ;;
esac

need() { command -v "$1" >/dev/null 2>&1 || { err "缺少 $1，请先执行：sudo dnf install $2"; exit 1; }; }
need ar binutils
need curl curl
need python3 python3

local_version() { [ -f "$VER_FILE" ] && cat "$VER_FILE" || echo ""; }

# 只下载 deb 头部，解析 control 里的 Version 字段
remote_version() {
  local head="$1/head.deb"
  curl -sSL --max-time 180 -r "0-$HEAD_BYTES" -o "$head" "$DEB_URL" || return 1
  python3 - "$head" <<'PY'
import sys, io, tarfile, gzip
def read_ar(p):
    f = open(p, 'rb')
    if f.read(8) != b'!<arch>\n':
        return {}
    out = {}
    while True:
        h = f.read(60)
        if len(h) < 60:
            break
        name = h[0:16].decode('ascii', 'replace').strip().rstrip('/')
        try:
            size = int(h[48:58].decode('ascii').strip())
        except ValueError:
            break
        out[name] = f.read(size)
        if size % 2:
            f.read(1)
    return out
m = read_ar(sys.argv[1])
blob = m.get('control.tar.gz')
if not blob:
    sys.exit(2)
t = tarfile.open(fileobj=io.BytesIO(gzip.decompress(blob)))
for n in t.getnames():
    if n.split('/')[-1] == 'control':
        for line in t.extractfile(n).read().decode('utf-8', 'replace').splitlines():
            if line.startswith('Version:'):
                print(line.split(':', 1)[1].strip())
                sys.exit(0)
sys.exit(2)
PY
}

do_uninstall() {
  info "卸载有道云笔记..."
  $SUDO rm -rf "$APP_DIR"
  $SUDO rm -f  "/usr/bin/$BIN_NAME"
  $SUDO rm -f  "/usr/share/applications/$DESKTOP_FILE"
  $SUDO sh -c "rm -f /usr/share/icons/hicolor/*/apps/$BIN_NAME.png" || true
  $SUDO gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
  $SUDO update-desktop-database /usr/share/applications 2>/dev/null || true
  ok "已卸载（用户数据保留在 ~/.config/ 下，未触碰）"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ "$MODE" = "uninstall" ]; then do_uninstall; exit 0; fi

# ---------------- 版本比对 ----------------
CUR="$(local_version)"
info "获取远端版本信息（只下载前 256 KB）..."
if REMOTE="$(remote_version "$TMP")" && [ -n "$REMOTE" ]; then
  if [ -n "$CUR" ]; then info "已安装：$CUR"; else info "本地未检测到已安装版本（将执行全新安装）"; fi
  info "远端最新：$REMOTE"
else
  warn "无法读取远端版本号，将直接执行完整安装"
  REMOTE=""
fi

if [ "$MODE" = "check" ]; then
  [ -z "$REMOTE" ] && { err "检查失败"; exit 1; }
  if [ "$CUR" = "$REMOTE" ]; then ok "已是最新版本"; else warn "有新版本：${CUR:-未安装} → $REMOTE"; fi
  exit 0
fi

if [ "$FORCE" != "1" ] && [ -n "$REMOTE" ] && [ "$CUR" = "$REMOTE" ]; then
  ok "已是最新版本（$CUR），无需下载。想强制重装请加 --force"
  exit 0
fi

# ---------------- 完整下载与安装 ----------------
cd "$TMP"
info "下载完整 deb（约 161 MB，请稍候）..."
curl -#SL --max-time 900 -o ynote.deb "$DEB_URL"
ok "下载完成：$(du -h ynote.deb | cut -f1)"

info "拆包..."
ar x ynote.deb
tar -xf data.tar.xz

info "安装运行依赖（已装的会自动跳过）..."
$SUDO dnf install -y gtk3 libnotify nss libXScrnSaver libXtst xdg-utils \
                    at-spi2-core libuuid libsecret libayatana-appindicator-gtk3

info "写入 $APP_DIR ..."
$SUDO rm -rf "$APP_DIR"
$SUDO cp -r opt/有道云笔记 /opt/
$SUDO mkdir -p /usr/share/applications /usr/share/icons
$SUDO cp    usr/share/applications/$DESKTOP_FILE /usr/share/applications/
$SUDO cp -r usr/share/icons/hicolor/. /usr/share/icons/hicolor/

# 复现 deb 的 postinst 在 Fedora 上做不到的两件事
$SUDO ln -sf "$APP_DIR/$BIN_NAME" "/usr/bin/$BIN_NAME"
$SUDO chmod 4755 "$APP_DIR/chrome-sandbox" 2>/dev/null || true

$SUDO gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
$SUDO update-desktop-database /usr/share/applications 2>/dev/null || true

# 记录版本，供下次比对
if [ -n "$REMOTE" ]; then echo "$REMOTE" | $SUDO tee "$VER_FILE" >/dev/null; fi

if [ -n "$CUR" ]; then
  ok "升级完成：$CUR → ${REMOTE:-未知}"
else
  ok "安装完成：${REMOTE:-未知}"
fi
info "可从应用菜单搜「有道云笔记」启动，或终端执行 $BIN_NAME"
printf '    想让程序自带的「检查更新」也能用：sudo chown -R "%s:%s" "%s"\n' "$USER" "$USER" "$APP_DIR"
