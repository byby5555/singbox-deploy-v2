#!/usr/bin/env bash
# ============================================================
# singbox-deploy-v2 / protocols/trojan.sh
# Trojan 协议模块：配置生成 / 重置 / 新增节点 / URI
# ============================================================

# Trojan 入站 JSON
trojan_inbound_json() {
    local port="$1" password="$2" tag="$3" sni="$4"
    cat <<JSON
{
  "type": "trojan",
  "listen": "::",
  "listen_port": $port,
  "users": [
    {"name": "user1", "password": "$password"}
  ],
  "tls": {
    "enabled": true,
    "certificate": "self",
    "insecure": true,
    "server_name": "$sni"
  },
  "tag": "$tag"
}
JSON
}

# 生成 Trojan 入站配置段
trojan_build_inbound() {
    if [ "${ENABLE_TROJAN:-false}" = "true" ]; then
        [ -z "$TROJAN_PORT" ] && TROJAN_PORT=$(rand_port)
        [ -z "$TROJAN_PASSWORD" ] && TROJAN_PASSWORD=$(rand_pass)
        [ -z "$TROJAN_SNI" ] && TROJAN_SNI="www.bing.com"
        TROJAN_TAG="trojan-in"
        export TROJAN_PORT TROJAN_PASSWORD TROJAN_SNI TROJAN_TAG
        build_config_append_inbound "$(trojan_inbound_json "$TROJAN_PORT" "$TROJAN_PASSWORD" "$TROJAN_TAG" "$TROJAN_SNI")"
    fi
}

# 重置 Trojan 端口
reset_trojan_port() {
    local new_port
    read -p "请输入新的 Trojan 端口(留空随机): " new_port
    [ -z "$new_port" ] && new_port=$(rand_port)
    if [ -f "$SB_CONFIG_FILE" ]; then
        jq --argjson port "$new_port" \
           '.inbounds |= map(if .type=="trojan" then .listen_port = $port else . end)' \
           "$SB_CONFIG_FILE" > "$SB_CONFIG_FILE.tmp" && mv "$SB_CONFIG_FILE.tmp" "$SB_CONFIG_FILE"
        TROJAN_PORT="$new_port"
        write_cache
        info "Trojan 端口已更新: $new_port"
        service_restart && generate_uris
    else
        err "配置文件不存在"
        return 1
    fi
}

# 新增 Trojan 节点
add_trojan_node() {
    info "=== 新增 Trojan 节点 ==="
    read -p "节点名称(可留空): " trojan_name
    read -p "端口(留空随机): " trojan_port
    [ -z "$trojan_port" ] && trojan_port=$(rand_port)
    read -p "密码(留空自动生成): " trojan_password
    [ -z "$trojan_password" ] && trojan_password=$(rand_pass)

    local trojan_sni
    trojan_sni=$(select_sni "hy2_tuic")

    local tag="trojan-${trojan_name:-$(rand_port)}"
    jq --argjson port "$trojan_port" --arg password "$trojan_password" --arg sni "$trojan_sni" --arg tag "$tag" \
       '.inbounds += [{"type":"trojan","listen":"::","listen_port":$port,"users":[{"name":"user1","password":$password}],"tls":{"enabled":true,"certificate":"self","insecure":true,"server_name":$sni},"tag":$tag}]' \
       "$SB_CONFIG_FILE" > "$SB_CONFIG_FILE.tmp" && mv "$SB_CONFIG_FILE.tmp" "$SB_CONFIG_FILE"

    TROJAN_SNI="$trojan_sni"
    ENABLE_TROJAN=true
    save_protocols
    write_cache
    service_restart
    generate_uris
    ok "Trojan 节点已新增: $tag (端口 $trojan_port)"
}

# Trojan URI 生成
gen_trojan_uri() {
    local ip="${PUBLIC_IP:-$(get_public_ip)}"
    [ -z "$ip" ] && ip="YOUR_SERVER_IP"
    [ -n "${TROJAN_PORT:-}" ] || load_from_config
    local sni="${TROJAN_SNI:-www.bing.com}"
    local encoded
    encoded=$(url_encode "$TROJAN_PASSWORD")
    echo "Trojan:      trojan://${encoded}@${ip}:${TROJAN_PORT}/?security=tls&sni=${sni}&allowInsecure=1#Trojan"
}
