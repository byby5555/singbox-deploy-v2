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
        if sing-box check -c "$SB_CONFIG_FILE" >/dev/null 2>&1; then
            ok "配置校验通过"
        else
            err "配置校验失败，请检查: sing-box check -c $SB_CONFIG_FILE"
            return 1
        fi
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