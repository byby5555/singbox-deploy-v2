#!/usr/bin/env bash
# ============================================================
# singbox-deploy-v2 / protocols/ss.sh
# Shadowsocks (SS) 协议模块：配置生成 / 重置 / 新增节点 / URI
# ============================================================

# SS 入站 JSON（追加到 .inbounds）
ss_inbound_json() {
    local port="$1" method="$2" psk="$3" tag="$4"
    cat <<JSON
{
  "type": "shadowsocks",
  "listen": "::",
  "listen_port": $port,
  "method": "$method",
  "password": "$psk",
  "tag": "$tag"
}
JSON
}

# 生成 SS 入站配置段（供 create_config 调用）
ss_build_inbound() {
    if [ "${ENABLE_SS:-false}" = "true" ]; then
        [ -z "$SS_PORT" ] && SS_PORT=$(rand_port)
        [ -z "$SS_PSK" ] && SS_PSK=$(rand_pass)
        [ -z "$SS_METHOD" ] && SS_METHOD="2022-blake3-aes-128-gcm"
        SS_TAG="ss-in"
        export SS_PORT SS_PSK SS_METHOD SS_TAG
        build_config_append_inbound "$(ss_inbound_json "$SS_PORT" "$SS_METHOD" "$SS_PSK" "$SS_TAG")"
    fi
}

# 选择 SS 加密方式（交互）
select_ss_method() {
    info "=== 选择 Shadowsocks 加密方式 ==="
    echo "1) 2022-blake3-aes-128-gcm (推荐)"
    echo "2) 2022-blake3-aes-256-gcm"
    echo "3) 2022-blake3-chacha20-poly1305"
    echo "4) xchacha20-poly1305 (xchacha20-ietf-poly1305)"
    echo ""
    echo -n "请输入选择(默认为 1): "
    read -r choice
    case "${choice:-1}" in
        1) SS_METHOD="2022-blake3-aes-128-gcm" ;;
        2) SS_METHOD="2022-blake3-aes-256-gcm" ;;
        3) SS_METHOD="2022-blake3-chacha20-poly1305" ;;
        4) SS_METHOD="xchacha20-ietf-poly1305" ;;
        *) SS_METHOD="2022-blake3-aes-128-gcm" ;;
    esac
    info "已选择: $SS_METHOD"
    export SS_METHOD
}

# 重置 SS 端口
reset_ss_port() {
    local new_port
    read -p "请输入新的 SS 端口(留空随机): " new_port
    [ -z "$new_port" ] && new_port=$(rand_port)
    if [ -f "$SB_CONFIG_FILE" ]; then
        jq --argjson port "$new_port" \
           '.inbounds |= map(if .type=="shadowsocks" then .listen_port = $port else . end)' \
           "$SB_CONFIG_FILE" > "$SB_CONFIG_FILE.tmp" && mv "$SB_CONFIG_FILE.tmp" "$SB_CONFIG_FILE"
        SS_PORT="$new_port"
        write_cache
        info "SS 端口已更新: $new_port"
        service_restart && generate_uris
    else
        err "配置文件不存在"
        return 1
    fi
}

# 新增 SS 节点（自定义参数，追加 inbound）
add_ss_node() {
    info "=== 新增 SS 节点 ==="
    read -p "节点名称(可留空): " ss_name
    read -p "端口(留空随机): " ss_port
    [ -z "$ss_port" ] && ss_port=$(rand_port)

    info "加密方式:"
    echo "1) 2022-blake3-aes-128-gcm"
    echo "2) 2022-blake3-aes-256-gcm"
    echo "3) 2022-blake3-chacha20-poly1305"
    echo "4) xchacha20-ietf-poly1305"
    echo -n "选择(默认 1): "
    read -r m
    case "${m:-1}" in
        2) method="2022-blake3-aes-256-gcm" ;;
        3) method="2022-blake3-chacha20-poly1305" ;;
        4) method="xchacha20-ietf-poly1305" ;;
        *) method="2022-blake3-aes-128-gcm" ;;
    esac

    read -p "请输入密码(留空自动生成): " psk
    [ -z "$psk" ] && psk=$(rand_pass)

    local tag="ss-${ss_name:-$(rand_port)}"
    jq --argjson port "$ss_port" --arg method "$method" --arg psk "$psk" --arg tag "$tag" \
       '.inbounds += [{"type":"shadowsocks","listen":"::","listen_port":$port,"method":$method,"password":$psk,"tag":$tag}]' \
       "$SB_CONFIG_FILE" > "$SB_CONFIG_FILE.tmp" && mv "$SB_CONFIG_FILE.tmp" "$SB_CONFIG_FILE"

    ENABLE_SS=true
    save_protocols
    write_cache
    service_restart
    generate_uris
    ok "SS 节点已新增: $tag (端口 $ss_port)"
}

# SS URI 生成
gen_ss_uri() {
    local ip="${PUBLIC_IP:-$(get_public_ip)}"
    [ -z "$ip" ] && ip="YOUR_SERVER_IP"
    [ -n "${SS_PORT:-}" ] || load_from_config
    local encoded
    encoded=$(printf '%s:%s' "${SS_METHOD:-2022-blake3-aes-128-gcm}" "$SS_PSK" | base64 -w0 2>/dev/null | tr -d '=')
    echo "Shadowsocks:  ss://${encoded}@${ip}:${SS_PORT}#SS"
}