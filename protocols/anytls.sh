#!/usr/bin/env bash
# ============================================================
# singbox-deploy-v2 / protocols/anytls.sh
# AnyTLS 协议模块（sing-box 1.12.0+）
# 配置生成 / 重置 / 新增节点 / URI
# ============================================================

# AnyTLS 入站 JSON
anytls_inbound_json() {
    local port="$1" password="$2" tag="$3" sni="$4"
    cat <<JSON
{
  "type": "anytls",
  "listen": "::",
  "listen_port": $port,
  "users": [
    {"name": "user1", "password": "$password"}
  ],
  "tls": {
    "enabled": true,
    "certificate_path": "$SB_CERT_FILE",
    "key_path": "$SB_KEY_FILE",
    "server_name": "$sni"
  },
  "tag": "$tag"
}
JSON
}

# 生成 AnyTLS 入站配置段
anytls_build_inbound() {
    if [ "${ENABLE_ANYTLS:-false}" = "true" ]; then
        [ -z "${ANYTLS_PORT:-}" ] && ANYTLS_PORT=$(rand_port)
        [ -z "${ANYTLS_PASSWORD:-}" ] && ANYTLS_PASSWORD=$(rand_pass)
        [ -z "${ANYTLS_SNI:-}" ] && ANYTLS_SNI="www.bing.com"
        ANYTLS_TAG="anytls-in"
        export ANYTLS_PORT ANYTLS_PASSWORD ANYTLS_SNI ANYTLS_TAG
        build_config_append_inbound "$(anytls_inbound_json "$ANYTLS_PORT" "$ANYTLS_PASSWORD" "$ANYTLS_TAG" "$ANYTLS_SNI")"
    fi
}

# 重置 AnyTLS 端口
reset_anytls_port() {
    local new_port
    read -p "请输入新的 AnyTLS 端口(留空随机): " new_port
    [ -z "$new_port" ] && new_port=$(rand_port)
    if [ -f "$SB_CONFIG_FILE" ]; then
        jq --argjson port "$new_port" \
           '.inbounds |= map(if .type=="anytls" then .listen_port = $port else . end)' \
           "$SB_CONFIG_FILE" > "$SB_CONFIG_FILE.tmp" && mv "$SB_CONFIG_FILE.tmp" "$SB_CONFIG_FILE"
        ANYTLS_PORT="$new_port"
        write_cache
        info "AnyTLS 端口已更新: $new_port"
        service_restart && generate_uris
    else
        err "配置文件不存在"
        return 1
    fi
}

# 新增 AnyTLS 节点
add_anytls_node() {
    info "=== 新增 AnyTLS 节点 ==="
    read -p "节点名称(可留空): " anytls_name
    read -p "端口(留空随机): " anytls_port
    [ -z "$anytls_port" ] && anytls_port=$(rand_port)
    read -p "密码(留空自动生成): " anytls_password
    [ -z "$anytls_password" ] && anytls_password=$(rand_pass)

    local anytls_sni
    anytls_sni=$(select_sni "hy2_tuic")

    local tag="anytls-${anytls_name:-$(rand_port)}"
    jq --argjson port "$anytls_port" --arg password "$anytls_password" --arg sni "$anytls_sni" --arg tag "$tag" --arg cert "$SB_CERT_FILE" --arg key "$SB_KEY_FILE" \
       '.inbounds += [{"type":"anytls","listen":"::","listen_port":$port,"users":[{"name":"user1","password":$password}],"tls":{"enabled":true,"certificate_path":$cert,"key_path":$key,"server_name":$sni},"tag":$tag}]' \
       "$SB_CONFIG_FILE" > "$SB_CONFIG_FILE.tmp" && mv "$SB_CONFIG_FILE.tmp" "$SB_CONFIG_FILE"

    ANYTLS_SNI="$anytls_sni"
    ENABLE_ANYTLS=true
    save_protocols
    write_cache
    service_restart
    generate_uris
    ok "AnyTLS 节点已新增: $tag (端口 $anytls_port)"
}

# AnyTLS URI 生成
gen_anytls_uri() {
    local ip="${PUBLIC_IP:-$(get_public_ip)}"
    [ -z "$ip" ] && ip="YOUR_SERVER_IP"
    [ -n "${ANYTLS_PORT:-}" ] || load_from_config
    local sni="${ANYTLS_SNI:-www.bing.com}"
    local encoded
    encoded=$(url_encode "$ANYTLS_PASSWORD")
    echo "AnyTLS:      anytls://${encoded}@${ip}:${ANYTLS_PORT}/?insecure=1&sni=${sni}#AnyTLS"
}
