---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '9ba2d4be-4640-483b-b6cf-12a621a71c66'
  PropagateID: '9ba2d4be-4640-483b-b6cf-12a621a71c66'
  ReservedCode1: '74e2cc67-62e3-456a-8c88-a5c30d4241c9'
  ReservedCode2: '74e2cc67-62e3-456a-8c88-a5c30d4241c9'
---

# 架构说明

singbox-deploy-v2 采用模块化设计，将原有单文件脚本拆分为**核心库** + **协议模块** + **管理面板**三层。

## 设计目标

1. **可维护**：修一个 bug 只改一个文件，所有协议受益
2. **可扩展**：新增协议只需在 `protocols/` 添加一个模块文件，实现固定的函数接口
3. **可插拔**：协议开关由 `.protocols` 文件驱动，安装时动态组装

## 模块职责

| 模块 | 职责 | 关键函数 |
|---|---|---|
| `core/common.sh` | 公共工具：日志、随机、OS 检测、缓存、URI | `info/err`、`rand_port`、`detect_os`、`generate_uris` |
| `core/install.sh` | sing-box 安装/更新/卸载 | `install_deps`、`install_singbox`、`update_singbox` |
| `core/service.sh` | systemd/OpenRC 服务管理 | `install_service`、`service_start/stop/restart/status` |
| `core/config.sh` | 生成 config.json | `build_full_config`、`build_config_append_inbound` |
| `protocols/ss.sh` | Shadowsocks | `ss_build_inbound`、`gen_ss_uri`、`reset_ss_port`、`add_ss_node` |
| `protocols/hy2.sh` | Hysteria2 | `hy2_build_inbound`、`gen_hy2_uri`、`reset_hy2_port` |
| `protocols/tuic.sh` | TUIC | `tuic_build_inbound`、`gen_tuic_uri`、`reset_tuic_port` |
| `protocols/vless-reality.sh` | VLESS Reality | `reality_build_inbound`、`gen_reality_uri`、`reset_reality_port` |
| `protocols/vmess.sh` | VMess | `vmess_build_inbound`、`gen_vmess_uri`、`reset_vmess_port`、`add_vmess_node` |

## 新增协议三步走

1. 在 `protocols/` 新建 `myproto.sh`
2. 实现四个接口：
   - `myproto_build_inbound`：生成入站 JSON（调用 `build_config_append_inbound`）
   - `gen_myproto_uri`：生成客户端 URI
   - `reset_myproto_port`：重置端口（可选）
   - `add_myproto_node`：新增节点（可选）
3. 在 `install.sh`、`sb-menu.sh` 中注册协议名

## 部署流程

```
install.sh
  ├── require_root / detect_os / check_deps
  ├── 交互式选择协议 → save_protocols
  ├── install_deps / install_singbox
  ├── 各协议 *_build_inbound → build_full_config
  ├── install_service（systemd/OpenRC）
  ├── generate_uris（输出节点链接）
  └── install_sb_menu（部署 sb 管理面板）
```

## 兼容性

- 兼容原 singbox-deploy 的配置缓存格式（`.config_cache`、`.protocols`）
- 支持远程管道一键安装：`bash -c "$(curl -fsSL ...)"`
- 支持 Alpine / Debian / Ubuntu / CentOS / RHEL / Fedora

> AI生成