# some-scripts
常用脚本

## 脚本列表

- **Ubuntu更换阿里镜像源.sh** - Ubuntu 系统更换为阿里云镜像源
- **arch清理脚本.sh** - Arch Linux 系统更新与清理（更新系统、清理孤立包、清理缓存、清理日志）
- **rust更新脚本.sh** - Rust 工具链更新（rustup、cargo 及 cargo install 安装的包）
- **npm更新脚本.sh** - npm 全局包更新
- **update-ynote.sh** - 有道云笔记 Linux 客户端安装 / 升级 / 卸载（Fedora，拆包 .deb）

## 故障排查：有道云笔记启动后显示「加载遇到点问题」

### 现象

用 `update-ynote.sh` 安装的有道云笔记，启动后主界面不显示内容，只提示「加载遇到点问题」。

### 根因

1. 客户端主窗口由本地服务（`http://127.0.0.1:3334`）加载前端，前端再转发 API 请求到 `note.youdao.com`。
2. 二维码登录成功后，拉取用户信息的请求 `GET note.youdao.com/yws/mapi/user?method=get` 返回了 HTTP 503：
   `upstream connect error or disconnect/reset before headers. reset reason: connection failure`。
3. 用户信息拉取失败 → `currentUser` 为空 → 本地数据库报「没有登录的用户」→ 所有笔记接口返回 500 → 前端白屏提示「加载遇到点问题」。
4. 503 的直接诱因是机器上运行的 **Clash Verge（mihomo）** 开启了 TUN + fake-ip DNS：`note.youdao.com` 被解析成 `198.18.0.222`（`198.18.0.0/15` 假 IP 段），请求被代理到非直连链路，有道 CDN 上游因此返回 503。

### 排查日志位置

```
~/.config/ynote-desktop/myLogs/log-YYYY-M-D
~/.config/ynote-desktop/myLogs/log-bootstrap
```

关键报错关键字：`503`、`upstream connect error`、`[database]: 没有登录的用户`、`setCurrentUser: undefined`。

### 解决 / 规避

- **让有道域名走直连**：在 Clash 规则里把 `note.youdao.com`、`*.youdao.com`、`*.netease.com` 设为 `DIRECT`。
- 或者临时关闭 Clash（TUN）后再启动客户端。
- 重启客户端并重新登录。

## 故障排查：1Panel 装好后 `docker-compose` 命令不可用

### 现象

用 1Panel 装好 Docker 环境后，`docker-compose` 报「未找到命令」，但 `docker compose` 正常。

### 根因

1Panel 默认安装的是 **Docker Compose v2 插件**，位于 `/usr/libexec/docker/cli-plugins/docker-compose`，对应的命令是 `docker compose`（空格）。
老的 `docker-compose`（连字符）是 v1 时代的独立二进制，默认不再安装，所以直接敲会找不到命令。

### 解决

- **直接改用新命令**（推荐）：`docker compose up -d`、`docker compose ps`、`docker compose logs -f`。
- **做软链接**，保留 `docker-compose` 的敲法：

  ```bash
  sudo ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
  ```

- **加别名**（只影响当前 shell，fish 用户写到 `~/.config/fish/config.fish`）：

  ```bash
  alias docker-compose='docker compose'
  ```
