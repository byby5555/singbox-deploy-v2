#!/usr/bin/env bash
# ============================================================
# singbox-deploy-v2 / core/config.sh
# 配置生成器：组装 inbounds / outbounds / 完整 config.json
# 依赖：core/common.sh（已提供全局变量与工具函数）
# ============================================================

# 暂存待追加的 inbound JSON 段
INBOUNDS_JSON=""

# 追加一段 inbound JSON（协议模块调用）
build_config_append_inbound() {
    INBOUNDS_JSON="${INBOUNDS_JSON}${1},"
}

# 生成完整 config.json
build_full_config() {
    mkdir -p "$SB_CONFIG_DIR"

    # 组装 inbounds（去除尾部逗号）
    local inbounds="${INBOUNDS_JSON%,}"

    cat > "$SB_CONFIG_FILE" <<EOF
{
  "log": {"level": "info", "timestamp": true},
  "inbounds": [
${inbounds}
  ],
  "outbounds": [
    {"type": "direct", "tag": "direct-out"}
  ]
}
EOF

    # 配置校验
    if command -v sing-box >/dev/null 2>&1; then
        if ! sing-box check -c "$SB_CONFIG_FILE" >/dev/null 2>&1; then
            err "配置校验失败，详细错误："
            sing-box check -c "$SB_CONFIG_FILE" 2>&1 | head -n 20
            err "请检查: $SB_CONFIG_FILE"
            return 1
        fi
        ok "配置校验通过"
    fi
    return 0
}

# 备份当前配置
backup_config() {
    [ -f "$SB_CONFIG_FILE" ] && cp "$SB_CONFIG_FILE" "$SB_CONFIG_FILE.bak.$(date +%s)"
}

# 查看配置
view_config() {
    [ -f "$SB_CONFIG_FILE" ] && cat "$SB_CONFIG_FILE" || err "配置文件不存在"
}

# 编辑配置
edit_config() {
    [ -f "$SB_CONFIG_FILE" ] || { err "配置文件不存在，请先安装"; return 1; }
    if command -v nano >/dev/null 2>&1; then
        nano "$SB_CONFIG_FILE"
    elif command -v vi >/dev/null 2>&1; then
        vi "$SB_CONFIG_FILE"
    else
        err "未找到可用编辑器 (nano/vi)"
        return 1
    fi
}

# 导出配置（含 Reality 私钥等敏感信息，提示妥善保管）
export_config() {
    [ -f "$SB_CONFIG_FILE" ] || { err "配置文件不存在，请先安装"; return 1; }
    local path
    read -p "请输入导出路径(留空默认 ~/sing-box-config-日期.json): " path
    path="$(echo "$path" | tr -d '[:space:]')"
    [ -z "$path" ] && path="$HOME/sing-box-config-$(date +%Y%m%d-%H%M%S).json"
    if cp -f "$SB_CONFIG_FILE" "$path"; then
        ok "配置已导出: $path"
        info "提示: 文件包含 Reality 私钥等敏感信息，请妥善保管"
    else
        err "导出失败: $path"
        return 1
    fi
}

# 导入配置（校验 → 备份 → 应用 → 重启 → 同步状态 → 展示链接）
import_config() {
    local path latest_bak
    read -p "请输入要导入的配置文件路径: " path
    path="$(echo "$path" | tr -d '[:space:]')"
    [ -z "$path" ] && { warn "未输入路径"; return 1; }
    [ -f "$path" ] || { err "文件不存在: $path"; return 1; }
    command -v sing-box >/dev/null 2>&1 || { err "sing-box 未安装"; return 1; }

    # 先补生成缺失证书（HY2/TUIC/Trojan/AnyTLS 引用自签证书；必须在校验前，否则引用缺失证书的配置校验必失败）
    if grep -q "$SB_CERT_FILE" "$path" 2>/dev/null && \
       { [ ! -f "$SB_CERT_FILE" ] || [ ! -f "$SB_KEY_FILE" ]; }; then
        generate_self_signed_cert
    fi

    # 再校验配置合法性
    if ! sing-box check -c "$path" >/dev/null 2>&1; then
        err "配置校验未通过，无法导入:"
        sing-box check -c "$path" 2>&1 | head -n 5
        return 1
    fi

    # 备份当前配置 → 应用新配置
    backup_config
    cp -f "$path" "$SB_CONFIG_FILE"

    # 重启并验证；失败则回滚
    service_restart
    sleep 1
    if [ "$(check_running)" != "running" ]; then
        err "服务启动失败，回滚到原配置"
        latest_bak=$(ls -t "$SB_CONFIG_FILE".bak.* 2>/dev/null | head -n1)
        if [ -n "$latest_bak" ]; then
            cp -f "$latest_bak" "$SB_CONFIG_FILE"
            service_restart
        fi
        return 1
    fi

    # 从新配置同步运行状态（协议开关、端口/UUID、Reality 公钥推导）并持久化
    load_from_config
    save_protocols
    write_cache
    ok "配置已导入并重启服务"
    generate_uris
}