#!/usr/bin/env bash
# ============================================================
# singbox-deploy-v2 / core/common.sh
# 公共函数库：日志、随机生成、OS 检测、依赖安装、公共 IP
# 被 install.sh 与各协议模块 source
# ============================================================

# ---------- 全局路径 ----------
SB_CONFIG_DIR="/etc/sing-box"
SB_CONFIG_FILE="$SB_CONFIG_DIR/config.json"
SB_CACHE_FILE="$SB_CONFIG_DIR/.config_cache"
SB_PROTOCOL_FILE="$SB_CONFIG_DIR/.protocols"
SB_NAMES_FILE="/root/node_names.txt"
SB_CERT_FILE="$SB_CONFIG_DIR/cert.pem"
SB_KEY_FILE="$SB_CONFIG_DIR/key.pem"

# ---------- 颜色 ----------
C_INFO='\033[1;34m'
C_OK='\033[1;32m'
C_WARN='\033[1;33m'
C_ERR='\033[1;31m'
C_END='\033[0m'

info() { echo -e "${C_INFO}[INFO]${C_END} $*"; }
ok()   { echo -e "${C_OK}[OK]${C_END} $*"; }
warn() { echo -e "${C_WARN}[WARN]${C_END} $*"; }
err()  { echo -e "${C_ERR}[ERR]${C_END} $*" >&2; }

# ---------- 权限检查 ----------
require_root() {
    if [ "$(id -u)" != "0" ]; then
        err "必须以 root 运行"
        exit 1
    fi
}

# ---------- OS 检测 ----------
detect_os() {
    . /etc/os-release 2>/dev/null || true
    case "${ID:-}" in
        alpine) OS=alpine ;;
        debian|ubuntu) OS=debian ;;
        centos|rhel|fedora) OS=redhat ;;
        *) OS=unknown ;;
    esac
    export OS
}

# ---------- 随机数 / 密码 / UUID ----------
rand_port() {
    shuf -i 10000-60000 -n 1 2>/dev/null || echo $((RANDOM % 50001 + 10000))
}

rand_pass() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 16 | tr -d '\n\r'
    else
        head -c 16 /dev/urandom | base64 | tr -d '\n\r'
    fi
}

gen_uuid() {
    cat /proc/sys/kernel/random/uuid 2>/dev/null || \
        command -v uuidgen >/dev/null 2>&1 && uuidgen || \
        echo "00000000-0000-0000-0000-000000000000"
}

# ---------- 公网 IP ----------
get_public_ip() {
    for url in "https://api.ipify.org" "https://ipinfo.io/ip" "https://ifconfig.me" "https://icanhazip.com"; do
        ip=$(curl -s --max-time 5 "$url" 2>/dev/null | tr -d '[:space:]')
        [ -n "$ip" ] && [ "$ip" != "null" ] && echo "$ip" && return 0
    done
    echo ""
}

# ---------- URL 编码 ----------
url_encode() {
    printf '%s' "$1" | sed 's/:/%3A/g; s/+/%2B/g; s/\//%2F/g; s/=/%3D/g'
}

# ---------- 依赖检查 ----------
check_deps() {
    local missing=0
    for cmd in curl jq openssl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            warn "缺少依赖: $cmd"
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then
        err "请先安装缺失依赖 (curl jq openssl)"
        exit 1
    fi
    return 0
}

# ---------- 配置文件缓存读写 ----------
read_cache() {
    [ -f "$SB_CACHE_FILE" ] && . "$SB_CACHE_FILE" 2>/dev/null || true
}

write_cache() {
    mkdir -p "$SB_CONFIG_DIR"
    {
        echo "CUSTOM_IP=${CUSTOM_IP:-}"
        echo "REALITY_SNI=${REALITY_SNI:-addons.mozilla.org}"
        echo "ENABLE_SS=${ENABLE_SS:-false}"
        echo "ENABLE_HY2=${ENABLE_HY2:-false}"
        echo "ENABLE_TUIC=${ENABLE_TUIC:-false}"
        echo "ENABLE_REALITY=${ENABLE_REALITY:-false}"
    echo "ENABLE_VMESS=${ENABLE_VMESS:-false}"
    echo "ENABLE_TROJAN=${ENABLE_TROJAN:-false}"
    echo "ENABLE_ANYTLS=${ENABLE_ANYTLS:-false}"
    echo "SS_PORT=${SS_PORT:-}"
        echo "SS_PSK=${SS_PSK:-}"
        echo "SS_METHOD=${SS_METHOD:-2022-blake3-aes-128-gcm}"
        echo "HY2_PORT=${HY2_PORT:-}"
        echo "HY2_PSK=${HY2_PSK:-}"
        echo "HY2_SNI=${HY2_SNI:-www.bing.com}"
        echo "TUIC_PORT=${TUIC_PORT:-}"
        echo "TUIC_UUID=${TUIC_UUID:-}"
        echo "TUIC_PSK=${TUIC_PSK:-}"
        echo "TUIC_SNI=${TUIC_SNI:-www.bing.com}"
        echo "REALITY_PORT=${REALITY_PORT:-}"
        echo "REALITY_UUID=${REALITY_UUID:-}"
        echo "REALITY_PK=${REALITY_PK:-}"
        echo "REALITY_PUB=${REALITY_PUB:-}"
        echo "REALITY_SID=${REALITY_SID:-}"
        echo "VMESS_PORT=${VMESS_PORT:-}"
        echo "VMESS_UUID=${VMESS_UUID:-}"
        echo "TROJAN_PORT=${TROJAN_PORT:-}"
        echo "TROJAN_PASSWORD=${TROJAN_PASSWORD:-}"
        echo "TROJAN_SNI=${TROJAN_SNI:-www.bing.com}"
        echo "ANYTLS_PORT=${ANYTLS_PORT:-}"
        echo "ANYTLS_PASSWORD=${ANYTLS_PASSWORD:-}"
        echo "ANYTLS_SNI=${ANYTLS_SNI:-www.bing.com}"
    } > "$SB_CACHE_FILE"
}

# ---------- 协议开关读写 ----------
save_protocols() {
    mkdir -p "$SB_CONFIG_DIR"
    cat > "$SB_PROTOCOL_FILE" <<EOF
ENABLE_SS=${ENABLE_SS:-false}
ENABLE_HY2=${ENABLE_HY2:-false}
ENABLE_TUIC=${ENABLE_TUIC:-false}
ENABLE_REALITY=${ENABLE_REALITY:-false}
ENABLE_VMESS=${ENABLE_VMESS:-false}
ENABLE_TROJAN=${ENABLE_TROJAN:-false}
ENABLE_ANYTLS=${ENABLE_ANYTLS:-false}
EOF
}

load_protocols() {
    [ -f "$SB_PROTOCOL_FILE" ] && . "$SB_PROTOCOL_FILE" 2>/dev/null || true
}

# ---------- 生成自签名证书 ----------
generate_self_signed_cert() {
    mkdir -p "$SB_CONFIG_DIR"
    if [ -f "$SB_CERT_FILE" ] && [ -f "$SB_KEY_FILE" ]; then
        info "自签名证书已存在，跳过生成"
        return 0
    fi
    info "生成自签名证书..."
    # 优先使用 EC prime256v1（体积小、性能好），回退 RSA 2048
    openssl ecparam -genkey -name prime256v1 -out "$SB_KEY_FILE" 2>/dev/null || \
        openssl genrsa -out "$SB_KEY_FILE" 2048 2>/dev/null
    openssl req -new -x509 -days 3650 -key "$SB_KEY_FILE" -out "$SB_CERT_FILE" \
        -subj "/CN=www.bing.com" 2>/dev/null
    chmod 600 "$SB_KEY_FILE"
    ok "自签名证书已生成: $SB_CERT_FILE"
}

# ---------- 生成 Reality 密钥对 ----------
generate_reality_keys() {
    if command -v sing-box >/dev/null 2>&1; then
        REALITY_KEYS=$(sing-box generate reality-keypair 2>/dev/null || echo "")
        REALITY_PK=$(echo "$REALITY_KEYS" | grep "PrivateKey" | awk '{print $NF}' | tr -d '\r' || echo "")
        REALITY_PUB=$(echo "$REALITY_KEYS" | grep "PublicKey" | awk '{print $NF}' | tr -d '\r' || echo "")
        REALITY_SID=$(openssl rand -hex 4 2>/dev/null || echo "123456")
        export REALITY_PK REALITY_PUB REALITY_SID
    else
        warn "sing-box 未安装，无法生成 Reality 密钥"
    fi
}

# ---------- 从 config.json 读取已部署协议参数 ----------
load_from_config() {
    [ -f "$SB_CONFIG_FILE" ] || return 0
    SS_PORT=$(jq -r '.inbounds[] | select(.type=="shadowsocks") | .listen_port // empty' "$SB_CONFIG_FILE" | head -n1)
    SS_PSK=$(jq -r '.inbounds[] | select(.type=="shadowsocks") | .password // empty' "$SB_CONFIG_FILE" | head -n1)
    SS_METHOD=$(jq -r '.inbounds[] | select(.type=="shadowsocks") | .method // empty' "$SB_CONFIG_FILE" | head -n1)
    HY2_PORT=$(jq -r '.inbounds[] | select(.type=="hysteria2") | .listen_port // empty' "$SB_CONFIG_FILE" | head -n1)
    HY2_PSK=$(jq -r '.inbounds[] | select(.type=="hysteria2") | .users[0].password // empty' "$SB_CONFIG_FILE" | head -n1)
    HY2_SNI=$(jq -r '.inbounds[] | select(.type=="hysteria2") | .tls.server_name // empty' "$SB_CONFIG_FILE" | head -n1)
    TUIC_PORT=$(jq -r '.inbounds[] | select(.type=="tuic") | .listen_port // empty' "$SB_CONFIG_FILE" | head -n1)
    TUIC_UUID=$(jq -r '.inbounds[] | select(.type=="tuic") | .users[0].uuid // empty' "$SB_CONFIG_FILE" | head -n1)
    TUIC_PSK=$(jq -r '.inbounds[] | select(.type=="tuic") | .users[0].password // empty' "$SB_CONFIG_FILE" | head -n1)
    TUIC_SNI=$(jq -r '.inbounds[] | select(.type=="tuic") | .tls.server_name // empty' "$SB_CONFIG_FILE" | head -n1)
    REALITY_PORT=$(jq -r '.inbounds[] | select(.type=="vless") | .listen_port // empty' "$SB_CONFIG_FILE" | head -n1)
    REALITY_UUID=$(jq -r '.inbounds[] | select(.type=="vless") | .users[0].uuid // empty' "$SB_CONFIG_FILE" | head -n1)
    REALITY_PK=$(jq -r '.inbounds[] | select(.type=="vless") | .tls.reality.private_key // empty' "$SB_CONFIG_FILE" | head -n1)
    REALITY_SID=$(jq -r '.inbounds[] | select(.type=="vless") | .tls.reality.short_id[0] // empty' "$SB_CONFIG_FILE" | head -n1)
    REALITY_SNI=$(jq -r '.inbounds[] | select(.type=="vless") | .tls.server_name // empty' "$SB_CONFIG_FILE" | head -n1)
    VMESS_PORT=$(jq -r '.inbounds[] | select(.type=="vmess") | .listen_port // empty' "$SB_CONFIG_FILE" | head -n1)
    VMESS_UUID=$(jq -r '.inbounds[] | select(.type=="vmess") | .users[0].uuid // empty' "$SB_CONFIG_FILE" | head -n1)
    TROJAN_PORT=$(jq -r '.inbounds[] | select(.type=="trojan") | .listen_port // empty' "$SB_CONFIG_FILE" | head -n1)
    TROJAN_PASSWORD=$(jq -r '.inbounds[] | select(.type=="trojan") | .users[0].password // empty' "$SB_CONFIG_FILE" | head -n1)
    TROJAN_SNI=$(jq -r '.inbounds[] | select(.type=="trojan") | .tls.server_name // empty' "$SB_CONFIG_FILE" | head -n1)
    ANYTLS_PORT=$(jq -r '.inbounds[] | select(.type=="anytls") | .listen_port // empty' "$SB_CONFIG_FILE" | head -n1)
    ANYTLS_PASSWORD=$(jq -r '.inbounds[] | select(.type=="anytls") | .users[0].password // empty' "$SB_CONFIG_FILE" | head -n1)
    ANYTLS_SNI=$(jq -r '.inbounds[] | select(.type=="anytls") | .tls.server_name // empty' "$SB_CONFIG_FILE" | head -n1)
    export SS_PORT SS_PSK SS_METHOD HY2_PORT HY2_PSK HY2_SNI TUIC_PORT TUIC_UUID TUIC_PSK TUIC_SNI
    export REALITY_PORT REALITY_UUID REALITY_PK REALITY_SID REALITY_SNI VMESS_PORT VMESS_UUID
    export TROJAN_PORT TROJAN_PASSWORD TROJAN_SNI ANYTLS_PORT ANYTLS_PASSWORD ANYTLS_SNI
}

# ---------- SNI / 伪装域名选择 ----------
# 用法: select_sni "reality" 或 select_sni "hy2_tuic"
# 返回: 通过 echo 输出选定的 SNI（调用方用 $(select_sni ...) 捕获）
select_sni() {
    local mode="$1"
    local default_sni
    local options=()

    if [ "$mode" = "reality" ]; then
        # Reality 需要真实服务器 IP（非 CDN），支持 TLS 1.3 + H2
        default_sni="addons.mozilla.org"
        options=(
            "addons.mozilla.org|Mozilla 插件站(默认)"
            "www.swift.com|SWIFT 金融官网(低调)"
            "www.tesla.com|特斯拉官网"
            "www.lovelive-anime.jp|动漫官网(小众)"
            "dash.cloudflare.com|Cloudflare 面板"
        )
    else
        # HY2 / TUIC 仅客户端伪装，要求低
        default_sni="www.bing.com"
        options=(
            "www.bing.com|微软 Bing(默认)"
            "www.apple.com|苹果官网"
            "www.cloudflare.com|Cloudflare"
            "www.swift.com|SWIFT 金融(低调)"
            "www.tesla.com|特斯拉官网"
        )
    fi

    info "请选择 SNI / 伪装域名:" >&2
    local i=1
    for opt in "${options[@]}"; do
        local domain="${opt%%|*}"
        local desc="${opt##*|}"
        echo "  $i) $domain  ($desc)" >&2
        i=$((i+1))
    done
    echo "  $i) 自定义输入" >&2
    echo -n "请输入选择(默认 1): " >&2

    read -r choice
    local max=${#options[@]}
    local custom_idx=$((max+1))

    if [ -z "$choice" ] || [ "$choice" = "1" ]; then
        echo "$default_sni"
    elif [ "$choice" = "$custom_idx" ]; then
        echo -n "请输入自定义域名: " >&2
        read -r custom
        custom="$(echo "$custom" | tr -d '[:space:]')"
        if [ -n "$custom" ]; then
            echo "$custom"
        else
            echo "$default_sni"
        fi
    elif [ "$choice" -ge 2 ] && [ "$choice" -le "$max" ] 2>/dev/null; then
        local selected="${options[$((choice-1))]}"
        echo "${selected%%|*}"
    else
        warn "无效选择，使用默认: $default_sni" >&2
        echo "$default_sni"
    fi
}

# ---------- 生成 URI 汇总（各协议模块提供 gen_uri_$proto）----------
generate_uris() {
    local ip="${CUSTOM_IP:-$(get_public_ip)}"
    [ -z "$ip" ] && ip="YOUR_SERVER_IP"
    PUBLIC_IP="$ip"
    echo ""
    info "========== 节点连接信息 =========="
    [ "${ENABLE_SS:-false}" = "true" ] && gen_ss_uri
    [ "${ENABLE_HY2:-false}" = "true" ] && gen_hy2_uri
    [ "${ENABLE_TUIC:-false}" = "true" ] && gen_tuic_uri
    [ "${ENABLE_REALITY:-false}" = "true" ] && gen_reality_uri
    [ "${ENABLE_VMESS:-false}" = "true" ] && gen_vmess_uri
    [ "${ENABLE_TROJAN:-false}" = "true" ] && gen_trojan_uri
    [ "${ENABLE_ANYTLS:-false}" = "true" ] && gen_anytls_uri
    echo "================================="
}