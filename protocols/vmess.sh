#!/usr/bin/env bash
# ============================================================
# singbox-deploy-v2 / protocols/vmess.sh
# VMess over TCP (AEAD) 协议模块
# ============================================================

# VMess 入站 JSON
vmess_inbound_json() {
    local port="$1" uuid="$2" tag="$3"
    cat <<JSON
{
  "type": "vmess",
  "listen": "::",
  "listen_port": $port,
  "users": [
    {"uuid": "$uuid", "alterId": 0}
  ],
  "tag": "$tag"
}
JSON
}

# 生成 VMess 入站配置段
vmess_build_inbound() {
    if [ "${ENABLE_VMESS:-false}" = "true" ]; then
        [ -z "${VMESS_PORT:-}" ] && VMESS_PORT=$(rand_port)
        [ -z "${VMESS_UUID:-}" ] && VMESS_UUID=$(gen_uuid)
        VMESS_TAG="vmess-in"
        export VMESS_PORT VMESS_UUID VMESS_TAG
        build_config_append_inbound "$(vmess_inbound_json "$VMESS_PORT" "$VMESS_UUID" "$VMESS_TAG")"
    fi
}

# 重置 VMess 端口
reset_vmess_port() {
    local new_port
    read -p "请输入新的 VMess 端口(留空随机): " new_port
    [ -z "$new_port" ] && new_port=$(rand_port)
    if [ -f "$SB_CONFIG_FILE" ]; then
        jq --argjson port "$new_port" \
           '.inbounds |= map(if .type=="vmess" then .listen_port = $port else . end)' \
           "$SB_CONFIG_FILE" > "$SB_CONFIG_FILE.tmp" && mv "$SB_CONFIG_FILE.tmp" "$SB_CONFIG_FILE"
        VMESS_PORT="$new_port"
        write_cache
        info "VMess 端口已更新: $new_port"
        service_restart && generate_uris
    else
        err "配置文件不存在"
        return 1
    fi
}

# 新增 VMess 节点（自定义参数，追加 inbound）
add_vmess_node() {
    info "=== 新增 VMess 节点 ==="
    read -p "节点名称(可留空): " vmess_name
    read -p "端口(留空随机): " vmess_port
    [ -z "$vmess_port" ] && vmess_port=$(rand_port)
    read -p "UUID(留空自动生成): " vmess_uuid
    [ -z "$vmess_uuid" ] && vmess_uuid=$(gen_uuid)

    local tag="vmess-${vmess_name:-$(rand_port)}"
    jq --argjson port "$vmess_port" --arg uuid "$vmess_uuid" --arg tag "$tag" \
       '.inbounds += [{"type":"vmess","listen":"::","listen_port":$port,"users":[{"uuid":$uuid,"alterId":0}],"tag":$tag}]' \
       "$SB_CONFIG_FILE" > "$SB_CONFIG_FILE.tmp" && mv "$SB_CONFIG_FILE.tmp" "$SB_CONFIG_FILE"

    ENABLE_VMESS=true
    save_protocols
    write_cache
    service_restart
    generate_uris
    ok "VMess 节点已新增: $tag (端口 $vmess_port)"
}

# VMess URI 生成（标准 vmess://base64(JSON) 格式）
gen_vmess_uri() {
    local ip="${PUBLIC_IP:-$(get_public_ip)}"
    [ -z "$ip" ] && ip="YOUR_SERVER_IP"
    [ -n "${VMESS_PORT:-}" ] || load_from_config
    local payload
    payload=$(printf '{"v":"2","ps":"VMess","add":"%s","port":"%s","id":"%s","aid":"0","scy":"auto","net":"tcp","type":"none","tls":""}' \
        "$ip" "$VMESS_PORT" "$VMESS_UUID" | base64 -w0 2>/dev/null | tr -d '=')
    echo "VMess:       vmess://${payload}"
}