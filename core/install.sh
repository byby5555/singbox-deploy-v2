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
        debian)
            # 先安装 ca-certificates（apt HTTPS 源需要它），再装其他依赖
            # 若 ca-certificates 缺失且源为 HTTPS，临时切 HTTP 安装
            if ! dpkg -s ca-certificates >/dev/null 2>&1; then
                info "ca-certificates 缺失，尝试安装..."
                # 临时将 https:// 源改为 http://
                sed -i 's/https:\/\//http:\/\//g' /etc/apt/sources.list 2>/dev/null || true
                sed -i 's/https:\/\//http:\/\//g' /etc/apt/sources.list.d/*.list 2>/dev/null || true
                apt-get update -y 2>/dev/null || true
                apt-get install -y ca-certificates 2>/dev/null || true
                # 恢复 https://
                sed -i 's/http:\/\//https:\/\//g' /etc/apt/sources.list 2>/dev/null || true
                sed -i 's/http:\/\//https:\/\//g' /etc/apt/sources.list.d/*.list 2>/dev/null || true
            fi
            apt-get update -y && apt-get install -y curl jq openssl ca-certificates
            ;;
        redhat)
            # 同样先确保 ca-certificates
            if ! rpm -q ca-certificates >/dev/null 2>&1; then
                yum install -y ca-certificates 2>/dev/null || true
            fi
            yum install -y curl jq openssl ca-certificates
            ;;
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

# 卸载 sing-box-deploy 全部组件（二进制 + 服务 + 配置 + 证书 + 管理脚本）
# 注意：不卸载系统依赖包（curl/jq/openssl/ca-certificates），它们是系统常用工具
uninstall_all() {
    echo ""
    info "========== 卸载 sing-box-deploy 全部组件 =========="
    echo "将删除以下内容："
    echo "  - sing-box 二进制及系统包"
    echo "  - systemd/OpenRC 服务"
    echo "  - /etc/sing-box/ （配置、证书、缓存、部署脚本）"
    echo "  - /usr/local/bin/sb 管理命令"
    echo "  - /tmp/singbox-deploy-v2/ 临时文件"
    echo "  - sing-box_*_linux_*.deb 下载的安装包"
    echo "  （保留系统依赖: curl jq openssl ca-certificates）"
    echo ""
    read -p "确认完全卸载? 此操作不可恢复 (y/N): " confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && info "已取消" && return 0

    info "1/7 停止并移除服务..."
    case "$OS" in
        alpine)
            rc-update del sing-box default 2>/dev/null || true
            rc-service sing-box stop 2>/dev/null || true
            rm -f /etc/init.d/sing-box
            ;;
        debian)
            systemctl disable --now sing-box 2>/dev/null || true
            systemctl kill sing-box 2>/dev/null || true
            rm -f /etc/systemd/system/sing-box.service
            systemctl daemon-reload 2>/dev/null || true
            ;;
        redhat)
            systemctl disable --now sing-box 2>/dev/null || true
            systemctl kill sing-box 2>/dev/null || true
            rm -f /etc/systemd/system/sing-box.service
            systemctl daemon-reload 2>/dev/null || true
            ;;
        *)
            warn "未知系统类型: $OS，跳过服务移除"
            ;;
    esac

    info "2/7 终止残留进程..."
    pkill -TERM -x sing-box 2>/dev/null || true
    sleep 1
    pkill -KILL -x sing-box 2>/dev/null || true

    info "3/7 卸载 sing-box 系统包..."
    case "$OS" in
        alpine)  apk del sing-box 2>/dev/null || true ;;
        debian)  apt-get purge -y sing-box >/dev/null 2>&1 || true ;;
        redhat)  yum remove -y sing-box >/dev/null 2>&1 || true ;;
    esac

    info "4/7 删除二进制及管理命令..."
    rm -f /usr/bin/sing-box /usr/local/bin/sing-box /usr/local/bin/sb 2>/dev/null || true

    info "5/7 删除配置目录..."
    rm -rf /etc/sing-box 2>/dev/null || true

    info "6/7 清理临时文件..."
    rm -rf /tmp/singbox-deploy-v2 2>/dev/null || true
    rm -f /root/sing-box_*_linux_*.deb /tmp/sing-box_*_linux_*.deb 2>/dev/null || true

    info "7/7 验证清理结果..."
    local remain=0
    for path in /usr/bin/sing-box /usr/local/bin/sb /etc/sing-box /etc/systemd/system/sing-box.service /etc/init.d/sing-box /tmp/singbox-deploy-v2; do
        if [ -e "$path" ]; then
            warn "残留: $path"
            remain=1
        fi
    done
    if pgrep -x sing-box >/dev/null 2>&1; then
        warn "残留进程: $(pgrep -x sing-box | tr '\n' ' ')"
        remain=1
    fi

    if [ "$remain" -eq 0 ]; then
        ok "sing-box-deploy 已完全卸载，无残留"
    else
        warn "部分残留未能自动清除，请手动检查上述路径"
    fi
}