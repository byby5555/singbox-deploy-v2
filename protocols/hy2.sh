#!/usr/bin/env bash
# ============================================================
# singbox-deploy-v2 / protocols/hy2.sh
# Hysteria2 (HY2) 协议模块
# ============================================================

# HY2 入站 JSON
hy2_inbound_json() {
    local port="$1" psk="$2" tag="$3"
    cat <<JSON
{
  "type": "hysteria2",
  "listen": "::",
  "listen_port": $port,
  "users": [{"password": "$psk"}],
  "tls": {
    "enabled": true,
    "alpn": ["h3"],
    "insecure": true
  },
  "tag": "$tag"
}
JSON
}

# 生成 HY2 入站配置段
hy2_build_inbound() {
    if [ "${ENABLE_HY2:-false}" = "true" ]; then
        [ -z "$HY2_PORT" ] && HY2_PORT=$(rand_port)
        [ -z "$HY2_PSK" ] && HY2_PSK=$(rand_pass)
        HY2_TAG="hy2-in"
        export HY2_PORT HY2_PSK HY2_TAG
        build_config_append_inbound "$(hy2_inbound_json "$HY2_PORT" "$HY2_PSK" "$HY2_TAG")"
    fi
}

# 重置 HY2 端口
reset_hy2_port() {
    local new_port
    read -p "请输入新的 HY2 端口(留空随机): " new_port
    [ -z "$new_port" ] && new_port=$(rand_port)
    if [ -f "$SB_CONFIG_FILE" ]; then
        jq --argjson port "$new_port" \
           '.inbounds |= map(if .type=="hysteria2" then .listen_port = $port else . end)' \
           "$SB_CONFIG_FILE" > "$SB_CONFIG_FILE.tmp" && mv "$SB_CONFIG_FILE.tmp" "$SB_CONFIG_FILE"
        HY2_PORT="$new_port"
        write_cache
        info "HY2 端口已更新: $new_port"
        service_restart && generate_uris
    else
        err "配置文件不存在"
        return 1
    fi
}

# HY2 URI 生成
gen_hy2_uri() {
    local ip="${PUBLIC_IP:-$(get_public_ip)}"
    [ -z "$ip" ] && ip="YOUR_SERVER_IP"
    [ -n "${HY2_PORT:-}" ] || load_from_config
    local encoded
    encoded=$(url_encode "$HY2_PSK")
    echo "Hysteria2:   hy2://${encoded}@${ip}:${HY2_PORT}/?insecure=1&sni=www.bing.com&alpn=h3#HY2"
}