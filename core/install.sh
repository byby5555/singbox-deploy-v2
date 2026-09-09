#!/usr/bin/env bash
# ============================================================
# singbox-deploy-v2 / core/install.sh
# sing-box 二进制安装 / 更新 / 卸载
# ============================================================

# 安装系统依赖（按 OS）
install_deps() {
    info "安装系统依赖..."
    case "$OS" in
        alpine)  apk update && apk add --no-cache bash curl jq openssl ca-certificates ;;
        debian)  apt-get update -y && apt-get install -y curl jq openssl ca-certificates ;;
        redhat)  yum install -y curl jq openssl ca-certificates ;;
        *)       err "不支持的系统: $OS" && exit 1 ;;
    esac
}

# 安装 sing-box 二进制
install_singbox() {
    info "安装 sing-box..."
    case "$OS" in
        alpine)
            # Alpine 优先使用官方安装脚本（自动处理架构）
            bash <(curl -fsSL https://sing-box.app/install.sh) || {
                warn "官方脚本安装失败，尝试 edge 仓库..."
                apk add --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community sing-box || {
                    err "sing-box 安装失败" && return 1
                }
            }
            ;;
        *)
            bash <(curl -fsSL https://sing-box.app/install.sh) || { err "sing-box 安装失败" && return 1; }
            ;;
    esac

    if command -v sing-box >/dev/null 2>&1; then
        local ver
        ver=$(sing-box version 2>/dev/null | head -n1)
        ok "sing-box 安装成功: $ver"
        return 0
    else
        err "未检测到 sing-box 命令，安装可能失败"
        return 1
    fi
}

# 更新 sing-box
update_singbox() {
    info "开始更新 sing-box..."
    case "$OS" in
        alpine)
            apk update && apk upgrade sing-box || bash <(curl -fsSL https://sing-box.app/install.sh) || { err "更新失败" && return 1; }
            ;;
        *)
            bash <(curl -fsSL https://sing-box.app/install.sh) || { err "更新失败" && return 1; }
            ;;
    esac
    local ver
    ver=$(sing-box version 2>/dev/null | head -n1)
    ok "sing-box 已更新: $ver"
    service_restart
}

# 卸载 sing-box（仅二进制，保留配置）
uninstall_singbox() {
    read -p "确认卸载 sing-box? (y/N): " confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && info "已取消" && return 0

    info "正在卸载..."
    case "$OS" in
        alpine)
            rc-update del sing-box default 2>/dev/null || true
            rc-service sing-box stop 2>/dev/null || true
            rm -f /etc/init.d/sing-box
            apk del sing-box 2>/dev/null || true
            ;;
        *)
            systemctl disable --now sing-box 2>/dev/null || true
            systemctl kill sing-box 2>/dev/null || true
            rm -f /etc/systemd/system/sing-box.service
            systemctl daemon-reload 2>/dev/null || true
            apt purge -y sing-box >/dev/null 2>&1 || true
            ;;
    esac

    pkill -TERM -x sing-box 2>/dev/null || true
    sleep 1
    pkill -KILL -x sing-box 2>/dev/null || true
    rm -rf /usr/bin/sing-box /usr/local/bin/sb 2>/dev/null || true
    ok "sing-box 已卸载（配置保留于 $SB_CONFIG_DIR）"
}