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

# 新增 TUIC 节点
add_tuic_node() {
    info "=== 新增 TUIC 节点 ==="
    read -p "节点名称(可留空): " tuic_name
    read -p "端口(留空随机): " tuic_port
    [ -z "$tuic_port" ] && tuic_port=$(rand_port)
    read -p "UUID(留空自动生成): " tuic_uuid
    [ -z "$tuic_uuid" ] && tuic_uuid=$(gen_uuid)
    read -p "密码(留空自动生成): " tuic_psk
    [ -z "$tuic_psk" ] && tuic_psk=$(rand_pass)

    local tag="tuic-${tuic_name:-$(rand_port)}"
    jq --argjson port "$tuic_port" --arg uuid "$tuic_uuid" --arg psk "$tuic_psk" --arg tag "$tag" \
       '.inbounds += [{"type":"tuic","listen":"::","listen_port":$port,"users":[{"uuid":$uuid,"password":$psk}],"congestion_control":"bbr","tls":{"enabled":true,"certificate":"self","insecure":true},"tag":$tag}]' \
       "$SB_CONFIG_FILE" > "$SB_CONFIG_FILE.tmp" && mv "$SB_CONFIG_FILE.tmp" "$SB_CONFIG_FILE"

    ENABLE_TUIC=true
    save_protocols
    write_cache
    service_restart
    generate_uris
    ok "TUIC 节点已新增: $tag (端口 $tuic_port)"
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