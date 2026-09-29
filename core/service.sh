#!/usr/bin/env bash
# ============================================================
# singbox-deploy-v2 / core/service.sh
# sing-box 服务管理：systemd / OpenRC 通用
# ============================================================

SERVICE_NAME="sing-box"

# 安装服务（开机自启 + 崩溃自动拉起）
install_service() {
    info "配置开机自启服务..."
    if [ "$OS" = "alpine" ]; then
        cat > /etc/init.d/sing-box <<'SVC'
#!/sbin/openrc-run
name="sing-box"
command="/usr/bin/sing-box"
command_args="run -c /etc/sing-box/config.json"
command_background="yes"
pidfile="/run/sing-box.pid"
supervisor=supervise-daemon
supervise_daemon_args="--respawn-max 0 --respawn-delay 5"
depend() { need net; }
SVC
        chmod +x /etc/init.d/sing-box
        rc-update add sing-box default 2>/dev/null || true
        rc-service sing-box restart 2>/dev/null || rc-service sing-box start || true
    else
        cat > /etc/systemd/system/sing-box.service <<'SYSTEMD'
[Unit]
Description=Sing-box Service
After=network.target

[Service]
ExecStart=/usr/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
SYSTEMD
        systemctl daemon-reload
        systemctl enable sing-box 2>/dev/null || true
        systemctl restart sing-box 2>/dev/null || systemctl start sing-box 2>/dev/null || true
        # 验证服务是否真正启动
        sleep 1
        if systemctl is-active sing-box >/dev/null 2>&1; then
            ok "服务已配置开机自启"
        elif pgrep -x sing-box >/dev/null 2>&1; then
            ok "服务已启动（进程检测）"
        else
            warn "服务可能未成功启动，请运行: systemctl status sing-box"
        fi
    fi
}

# 卸载服务
remove_service() {
    if [ "$OS" = "alpine" ]; then
        rc-update del sing-box default 2>/dev/null || true
        rc-service sing-box stop 2>/dev/null || true
        rm -f /etc/init.d/sing-box
    else
        systemctl disable --now sing-box 2>/dev/null || true
        systemctl kill sing-box 2>/dev/null || true
        rm -f /etc/systemd/system/sing-box.service
        systemctl daemon-reload 2>/dev/null || true
    fi
}

# 启动
service_start() {
    if [ "$OS" = "alpine" ]; then
        rc-service sing-box start || rc-service sing-box restart || return 1
    else
        systemctl start sing-box || systemctl restart sing-box || return 1
    fi
    return 0
}

# 停止
service_stop() {
    if [ "$OS" = "alpine" ]; then
        rc-service sing-box stop || return 1
    else
        systemctl stop sing-box || return 1
    fi
    return 0
}

# 重启
service_restart() {
    if [ "$OS" = "alpine" ]; then
        rc-service sing-box restart || rc-service sing-box start || return 1
    else
        systemctl restart sing-box || return 1
    fi
    return 0
}

# 状态
service_status() {
    if [ "$OS" = "alpine" ]; then
        rc-service sing-box status 2>/dev/null || echo "sing-box 未运行"
    else
        systemctl status sing-box --no-pager 2>/dev/null | head -n 10 || echo "sing-box 未运行"
    fi
}

# 快速检测运行状态（供菜单头部显示，返回: "running" 或 "stopped"）
# 三重检测：systemd → pgrep → ps，任一命中即判定运行中
check_running() {
    # 1) 优先用 systemctl（systemd 系统最可靠）
    if command -v systemctl >/dev/null 2>&1 && \
       systemctl is-active sing-box >/dev/null 2>&1; then
        echo "running"
        return 0
    fi
    # 2) pgrep 精确匹配进程名
    if command -v pgrep >/dev/null 2>&1 && \
       pgrep -x sing-box >/dev/null 2>&1; then
        echo "running"
        return 0
    fi
    # 3) ps 兜底（pgrep 不可用或进程名不匹配时）
    # 注意: 必须匹配 'sing-box run' 而非 'sing-box'，否则会误匹配
    # sb-menu.sh 自身的 bash 进程（路径含 /etc/sing-box/）
    if ps aux 2>/dev/null | grep -v grep | grep -q '[s]ing-box run'; then
        echo "running"
        return 0
    fi
    echo "stopped"
}

# 获取 sing-box 版本（简短）
get_version() {
    sing-box version 2>/dev/null | head -n1 || echo "unknown"
}

# 获取 PID
get_pid() {
    local pid
    # 1) 优先用 systemctl
    if command -v systemctl >/dev/null 2>&1; then
        pid=$(systemctl show -p MainPID --value sing-box 2>/dev/null)
        if [ -n "$pid" ] && [ "$pid" != "0" ]; then
            echo "$pid"
            return 0
        fi
    fi
    # 2) pgrep
    if command -v pgrep >/dev/null 2>&1; then
        pid=$(pgrep -x sing-box 2>/dev/null | head -n1)
        if [ -n "$pid" ]; then
            echo "$pid"
            return 0
        fi
    fi
    # 3) ps 兜底（匹配 sing-box run，避免误匹配 sb-menu.sh 自身）
    pid=$(ps aux 2>/dev/null | grep -v grep | grep '[s]ing-box run' | awk '{print $2}' | head -n1)
    if [ -n "$pid" ]; then
        echo "$pid"
        return 0
    fi
    echo "-"
}

# 检查配置合法性（sing-box check）
check_config() {
    if [ -f "$SB_CONFIG_FILE" ]; then
        if command -v sing-box >/dev/null 2>&1; then
            sing-box check -c "$SB_CONFIG_FILE" 2>&1 && ok "配置校验通过" || warn "配置校验有告警（可能不影响运行）"
        fi
    else
        warn "配置文件不存在: $SB_CONFIG_FILE"
    fi
}