#!/usr/bin/env bash
# ============================================================
# singbox-deploy-v2 / install.sh
# 统一安装入口：交互式选择协议并部署
# 使用: curl -fsSL https://raw.githubusercontent.com/byby5555/singbox-deploy-v2/main/install.sh | bash
# ============================================================
set -euo pipefail

# ---------- 定位脚本目录（支持远程管道执行） ----------
# bash -c "..." 管道模式下 BASH_SOURCE 为空，无法 cd 取路径
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

REPO_BASE="https://raw.githubusercontent.com/byby5555/singbox-deploy-v2/main"

# 若通过管道执行（bash -c "$(curl ...)"），SCRIPT_DIR 为空或模块文件不存在 → 下载到临时目录
if [ -z "$SCRIPT_DIR" ] || [ ! -f "$SCRIPT_DIR/core/common.sh" ]; then
    SCRIPT_DIR="/tmp/singbox-deploy-v2"
    mkdir -p "$SCRIPT_DIR/core" "$SCRIPT_DIR/protocols" "$SCRIPT_DIR/menu"
    echo "[INFO] 下载模块文件到 $SCRIPT_DIR ..."
    for mod in common install service config; do
        curl -fsSL -o "$SCRIPT_DIR/core/$mod.sh" "$REPO_BASE/core/$mod.sh" || { echo "[ERR] 下载 core/$mod.sh 失败" >&2; exit 1; }
    done
    for proto in ss hy2 tuic vless-reality vmess trojan anytls; do
        curl -fsSL -o "$SCRIPT_DIR/protocols/$proto.sh" "$REPO_BASE/protocols/$proto.sh" || { echo "[ERR] 下载 protocols/$proto.sh 失败" >&2; exit 1; }
    done
    curl -fsSL -o "$SCRIPT_DIR/menu/sb-menu.sh" "$REPO_BASE/menu/sb-menu.sh" || { echo "[ERR] 下载 menu/sb-menu.sh 失败" >&2; exit 1; }
    echo "[OK] 模块下载完成"
fi

# ---------- source 全部模块 ----------
for mod in common install service config; do
    . "$SCRIPT_DIR/core/$mod.sh"
done
for proto in ss hy2 tuic vless-reality vmess trojan anytls; do
    . "$SCRIPT_DIR/protocols/$proto.sh"
done

# ---------- 预检查 ----------
require_root
detect_os
check_deps

info "========== Sing-box 模块化部署 v2 =========="
info "检测到系统: $OS"

# ---------- 默认部署 VLESS Reality ----------
ENABLE_SS=false; ENABLE_HY2=false; ENABLE_TUIC=false; ENABLE_REALITY=true; ENABLE_VMESS=false; ENABLE_TROJAN=false; ENABLE_ANYTLS=false
info "默认部署协议: VLESS Reality"
info "（如需其他协议，安装完成后输入 sb → 新增节点）"
save_protocols

# ---------- 连接 IP / SNI ----------
echo ""
echo "请输入节点连接 IP 或 DDNS域名(留空默认出口IP):"
read -r CUSTOM_IP
CUSTOM_IP="$(echo "$CUSTOM_IP" | tr -d '[:space:]')"

REALITY_SNI=$(select_sni "reality")

write_cache

# ---------- 安装依赖与 sing-box ----------
install_deps
if ! command -v sing-box >/dev/null 2>&1; then
    install_singbox || exit 1
fi

# ---------- 构建配置 ----------
backup_config
info "正在生成配置..."

# 需要使用自签名证书的协议：HY2 / TUIC / Trojan / AnyTLS
if $ENABLE_HY2 || $ENABLE_TUIC || $ENABLE_TROJAN || $ENABLE_ANYTLS; then
    generate_self_signed_cert
fi

$ENABLE_SS && ss_build_inbound
$ENABLE_HY2 && hy2_build_inbound
$ENABLE_TUIC && tuic_build_inbound
$ENABLE_REALITY && reality_build_inbound
$ENABLE_VMESS && vmess_build_inbound
$ENABLE_TROJAN && trojan_build_inbound
$ENABLE_ANYTLS && anytls_build_inbound
build_full_config || exit 1
write_cache

# ---------- 安装服务 ----------
install_service

# ---------- 输出节点信息 ----------
generate_uris

# ---------- 安装 sb 管理命令 ----------
# 将整个仓库部署到 /etc/sing-box/deploy/，sb 命令指向 sb-menu.sh
install_sb_menu() {
    local deploy_dir="/etc/sing-box/deploy"
    mkdir -p "$deploy_dir/core" "$deploy_dir/protocols"
    cp -f "$SCRIPT_DIR/core/common.sh" "$deploy_dir/core/"
    cp -f "$SCRIPT_DIR/core/install.sh" "$deploy_dir/core/"
    cp -f "$SCRIPT_DIR/core/service.sh" "$deploy_dir/core/"
    cp -f "$SCRIPT_DIR/core/config.sh" "$deploy_dir/core/"
    cp -f "$SCRIPT_DIR/protocols/ss.sh" "$deploy_dir/protocols/"
    cp -f "$SCRIPT_DIR/protocols/hy2.sh" "$deploy_dir/protocols/"
    cp -f "$SCRIPT_DIR/protocols/tuic.sh" "$deploy_dir/protocols/"
    cp -f "$SCRIPT_DIR/protocols/vless-reality.sh" "$deploy_dir/protocols/"
    cp -f "$SCRIPT_DIR/protocols/vmess.sh" "$deploy_dir/protocols/"
    cp -f "$SCRIPT_DIR/protocols/trojan.sh" "$deploy_dir/protocols/"
    cp -f "$SCRIPT_DIR/protocols/anytls.sh" "$deploy_dir/protocols/"
    cp -f "$SCRIPT_DIR/menu/sb-menu.sh" "$deploy_dir/sb-menu.sh"
    chmod +x "$deploy_dir/sb-menu.sh"
    cat > /usr/local/bin/sb <<'SB_EOF'
#!/usr/bin/env bash
exec bash /etc/sing-box/deploy/sb-menu.sh "$@"
SB_EOF
    chmod +x /usr/local/bin/sb
    ok "sb 管理命令已安装"
}

install_sb_menu

ok "安装完成！"

# ---------- 安装后：展示链接 → 询问是否新增更多节点 ----------
while true; do
    echo ""
    read -p "是否立即新增更多节点？(y/N): " add_more
    [[ ! "$add_more" =~ ^[Yy]$ ]] && break

    info "请选择协议:"
    echo "1) Shadowsocks (SS)"
    echo "2) Hysteria2 (HY2)"
    echo "3) TUIC"
    echo "4) VLESS Reality"
    echo "5) VMess (TCP)"
    echo "6) Trojan"
    echo "7) AnyTLS"
    echo "0) 不新增，退出"
    echo -n "请输入编号: "
    read -r add_choice
    [ "$add_choice" = "0" ] && break
    case "$add_choice" in
        1) add_ss_node ;;
        2) add_hy2_node ;;
        3) add_tuic_node ;;
        4) add_reality_node ;;
        5) add_vmess_node ;;
        6) add_trojan_node ;;
        7) add_anytls_node ;;
        *) warn "无效选项: $add_choice" ;;
    esac
done

echo ""
ok "全部完成！输入 sb 进入管理面板"