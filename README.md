---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '12a7c96d-5606-4ef6-a4a1-d87074581405'
  PropagateID: '12a7c96d-5606-4ef6-a4a1-d87074581405'
  ReservedCode1: 'e814a54a-e5e8-4b57-957b-cc3d21075a98'
  ReservedCode2: 'e814a54a-e5e8-4b57-957b-cc3d21075a98'
---

# Sing-box 模块化一键部署脚本 v2

一个跨平台、自动化、全兼容的 Sing-box 一键部署脚本（模块化重构版）。

基于 [singbox-deploy](https://github.com/byby5555/singbox-deploy) 重构，采用**模块化架构**，便于维护与扩展新协议。

## ✨ 特性

- **模块化架构**：核心库、服务管理、协议模块分离，新增协议只需添加一个模块文件
- **多协议支持**：SS / Hysteria2 / TUIC / VLESS Reality / VMess 可自由组合部署
- **多系统支持**：Alpine / Debian / Ubuntu / CentOS / RHEL / Fedora
- **开机自启**：自动配置 systemd / OpenRC，崩溃自动拉起
- **管理面板**：安装后输入 `sb` 进入交互式管理菜单
- **线路机支持**：从落地机生成线路机中转脚本

## 🚀 一键部署

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/byby5555/singbox-deploy-v2/main/install.sh)"
```

> 需要 root 权限。

## 📁 目录结构

```
singbox-deploy-v2/
├── install.sh              # 统一安装入口（交互式）
├── core/                   # 核心库
│   ├── common.sh           # 公共函数（日志/随机/OS检测/IP/URI）
│   ├── install.sh          # sing-box 安装/更新/卸载
│   ├── service.sh          # systemd/OpenRC 服务管理
│   └── config.sh           # 配置生成器（组装 config.json）
├── protocols/              # 协议模块（可插拔）
│   ├── ss.sh               # Shadowsocks
│   ├── hy2.sh              # Hysteria2
│   ├── tuic.sh             # TUIC
│   ├── vless-reality.sh    # VLESS + Reality
│   └── vmess.sh            # VMess (TCP+AEAD)
├── menu/
│   └── sb-menu.sh          # sb 管理面板
└── docs/                   # 文档
```

## 🎛 管理面板（sb）

安装完成后输入 `sb` 进入管理面板：

| 功能 | 说明 |
|---|---|
| 查看协议链接 | 显示所有已部署协议的客户端连接 URI |
| 查看/编辑配置 | 查看或编辑 `/etc/sing-box/config.json` |
| 重置 XX 端口 | 动态显示已启用协议的重置端口选项 |
| 启动/停止/重启/状态 | 服务管理 |
| 更新 sing-box | 在线升级到官方最新版 |
| 新增 SS / VMess 节点 | 动态添加节点 |
| 卸载 | 卸载 sing-box（保留配置） |

## 📄 支持的协议

| 协议 | 说明 |
|---|---|
| Shadowsocks | 支持 2022-blake3 系列加密 |
| Hysteria2 | QUIC 加速 |
| TUIC | QUIC 加速 |
| VLESS Reality | 抗封锁 TLS |
| VMess | TCP + AEAD |

## 🔧 环境变量

| 变量 | 说明 | 默认 |
|---|---|---|
| `SINGBOX_VMESS_UUID` | 自定义 VMess UUID | 自动生成 |
| `SINGBOX_PORT_VMESS` | 自定义 VMess 端口 | 随机 |
| `CUSTOM_IP` | 节点连接 IP/DDNS | 自动获取出口 IP |
| `REALITY_SNI` | Reality SNI | `addons.mozilla.org` |

## 📝 License

MIT

> AI生成