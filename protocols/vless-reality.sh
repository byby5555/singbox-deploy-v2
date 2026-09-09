#!/usr/bin/env bash
# ============================================================
# singbox-deploy-v2 / protocols/vless-reality.sh
# VLESS + Reality 协议模块
# ============================================================

# VLESS Reality 入站 JSON
reality_inbound_json() {
    local port="$1" uuid="$2" pk="$3" sid="$4" sni="$5" tag="$6"
    cat <<JSON
{
  "type": "vless",
  "listen": "::",
  "listen_port": $port,
  "users": [
    {"uuid": "$uuid", "flow": "xtls-rprx-vision"}
  ],
  "tls": {
    "enabled": true,
    "server_name": "$sni",
    "reality": {
      "enabled": true,
      "handshake": {"server": "$sni", "server_port": 443},
      "private_key": "$pk",
      "short_id": ["$sid"]
    }
  },
  "tag": "$tag"
}
JSON
}

# 生成 VLESS Reality 入站配置段
reality_build_inbound() {
    if [ "${ENABLE_REALITY:-false}" = "true" ]; then
        [ -z "$REALITY_PORT" ] && REALITY_PORT=$(rand_port)
        [ -z "$REALITY_UUID" ] && REALITY_UUID=$(gen_uuid)
        [ -z "$REALITY_PK" ] || [ -z "$REALITY_PUB" ] && generate_reality_keys
        [ -z "$REALITY_SID" ] && REALITY_SID=$(openssl rand -hex 4 2>/dev/null || echo "123456")
        [ -z "$REALITY_SNI" ] && REALITY_SNI="addons.mozilla.org"
        REALITY_TAG="vless-reality-in"
        export REALITY_PORT REALITY_UUID REALITY_PK REALITY_PUB REALITY_SID REALITY_SNI REALITY_TAG
        build_config_append_inbound "$(reality_inbound_json "$REALITY_PORT" "$REALITY_UUID" "$REALITY_PK" "$REALITY_SID" "$REALITY_SNI" "$REALITY_TAG")"
    fi
}

# 重置 Reality 端口
reset_reality_port() {
    local new_port
    read -p "请输入新的 Reality 端口(留空随机): " new_port
    [ -z "$new_port" ] && new_port=$(rand_port)
    if [ -f "$SB_CONFIG_FILE" ]; then
        jq --argjson port "$new_port" \
           '.inbounds |= map(if .type=="vless" then .listen_port = $port else . end)' \
           "$SB_CONFIG_FILE" > "$SB_CONFIG_FILE.tmp" && mv "$SB_CONFIG_FILE.tmp" "$SB_CONFIG_FILE"
        REALITY_PORT="$new_port"
        write_cache
        info "Reality 端口已更新: $new_port"
        service_restart && generate_uris
    else
        err "配置文件不存在"
        return 1
    fi
}

# 新增 VLESS Reality 节点
add_reality_node() {
    info "=== 新增 VLESS Reality 节点 ==="
    read -p "节点名称(可留空): " reality_name
    read -p "端口(留空随机): " reality_port
    [ -z "$reality_port" ] && reality_port=$(rand_port)
    read -p "UUID(留空自动生成): " reality_uuid
    [ -z "$reality_uuid" ] && reality_uuid=$(gen_uuid)
    read -p "SNI(留空默认 addons.mozilla.org): " reality_sni
    [ -z "$reality_sni" ] && reality_sni="addons.mozilla.org"

    info "生成 Reality 密钥对..."
    generate_reality_keys
    local sid
    sid=$(openssl rand -hex 4 2>/dev/null || echo "123456")

    local tag="reality-${reality_name:-$(rand_port)}"
    jq --argjson port "$reality_port" --arg uuid "$reality_uuid" --arg pk "$REALITY_PK" --arg sid "$sid" --arg sni "$reality_sni" --arg tag "$tag" \
       '.inbounds += [{"type":"vless","listen":"::","listen_port":$port,"users":[{"uuid":$uuid,"flow":"xtls-rprx-vision"}],"tls":{"enabled":true,"server_name":$sni,"reality":{"enabled":true,"handshake":{"server":$sni,"server_port":443},"private_key":$pk,"short_id":[$sid]}},"tag":$tag}]' \
       "$SB_CONFIG_FILE" > "$SB_CONFIG_FILE.tmp" && mv "$SB_CONFIG_FILE.tmp" "$SB_CONFIG_FILE"

    ENABLE_REALITY=true
    save_protocols
    write_cache
    service_restart
    generate_uris
    ok "Reality 节点已新增: $tag (端口 $reality_port)"
}

# VLESS Reality URI 生成
gen_reality_uri() {
    local ip="${PUBLIC_IP:-$(get_public_ip)}"
    [ -z "$ip" ] && ip="YOUR_SERVER_IP"
    [ -n "${REALITY_PORT:-}" ] || load_from_config
    local sid="${REALITY_SID:-}"
    echo "VLESS Reality:  vless://${REALITY_UUID}@${ip}:${REALITY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${REALITY_SNI}&fp=chrome&pbk=${REALITY_PUB}&sid=${sid}#Reality"
}