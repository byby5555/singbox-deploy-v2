#!/usr/bin/env bash
# ============================================================
# singbox-deploy-v2 / protocols/tuic.sh
# TUIC 协议模块
# ============================================================

# TUIC 入站 JSON
tuic_inbound_json() {
    local port="$1" uuid="$2" psk="$3" tag="$4"
    cat <<JSON
{
  "type": "tuic",
  "listen": "::",
  "listen_port": $port,
  "users": [
    {"uuid": "$uuid", "password": "$psk"}
  ],
  "congestion_control": "bbr",
  "tls": {
    "enabled": true,
    "certificate": "self",
    "insecure": true
  },
  "tag": "$tag"
}
JSON
}

# 生成 TUIC 入站配置段
tuic_build_inbound() {
    if [ "${ENABLE_TUIC:-false}" = "true" ]; then
        [ -z "$TUIC_PORT" ] && TUIC_PORT=$(rand_port)
        [ -z "$TUIC_UUID" ] && TUIC_UUID=$(gen_uuid)
        [ -z "$TUIC_PSK" ] && TUIC_PSK=$(rand_pass)
        TUIC_TAG="tuic-in"
        export TUIC_PORT TUIC_UUID TUIC_PSK TUIC_TAG
        build_config_append_inbound "$(tuic_inbound_json "$TUIC_PORT" "$TUIC_UUID" "$TUIC_PSK" "$TUIC_TAG")"
    fi
}

# 重置 TUIC 端口
reset_tuic_port() {
    local new_port
    read -p "请输入新的 TUIC 端口(留空随机): " new_port
    [ -z "$new_port" ] && new_port=$(rand_port)
    if [ -f "$SB_CONFIG_FILE" ]; then
        jq --argjson port "$new_port" \
           '.inbounds |= map(if .type=="tuic" then .listen_port = $port else . end)' \
           "$SB_CONFIG_FILE" > "$SB_CONFIG_FILE.tmp" && mv "$SB_CONFIG_FILE.tmp" "$SB_CONFIG_FILE"
        TUIC_PORT="$new_port"
        write_cache
        info "TUIC 端口已更新: $new_port"
        service_restart && generate_uris
    else
        err "配置文件不存在"
        return 1
    fi
}

# TUIC URI 生成
gen_tuic_uri() {
    local ip="${PUBLIC_IP:-$(get_public_ip)}"
    [ -z "$ip" ] && ip="YOUR_SERVER_IP"
    [ -n "${TUIC_PORT:-}" ] || load_from_config
    local encoded
    encoded=$(url_encode "$TUIC_PSK")
    echo "TUIC:        tuic://${TUIC_UUID}:${encoded}@${ip}:${TUIC_PORT}/?congestion_control=bbr&alpn=h3&sni=www.bing.com&insecure=1#TUIC"
}