#!/usr/bin/env bash
# ============================================================
# singbox-deploy-v2 / menu/sb-menu.sh
# sb 管理面板（部署到 /etc/sing-box/sb-menu.sh）
# 安装时会将整个仓库复制到 /etc/sing-box/deploy/ 下，
# 因此模块路径为 /etc/sing-box/deploy/...
# ============================================================
set -euo pipefail

DEPLOY_DIR="/etc/sing-box/deploy"
. "$DEPLOY_DIR/core/common.sh"
. "$DEPLOY_DIR/core/install.sh"
. "$DEPLOY_DIR/core/service.sh"
. "$DEPLOY_DIR/core/config.sh"
for proto in ss hy2 tuic vless-reality vmess trojan anytls; do
    . "$DEPLOY_DIR/protocols/$proto.sh"
done

detect_os
load_protocols
read_cache
load_from_config

show_menu() {
    # 运行状态检测
    local status_pid status_ver status_text status_color
    local running
    running=$(check_running)
    status_pid=$(get_pid)
    status_ver=$(get_version)
    if [ "$running" = "running" ]; then
        status_color='\033[1;32m'
        status_text="● 运行中"
    else
        status_color='\033[1;31m'
        status_text="○ 未运行"
    fi

    echo ""
    echo "=========================="
    echo " Sing-box 管理面板 (sb)"
    echo "=========================="
    echo -e " 状态: ${status_color}${status_text}${C_END} | PID: ${status_pid} | ${status_ver}"
    echo " --------------------------"
    cat <<'MENU'
 1) 查看协议链接
 2) 查看配置文件
 3) 编辑配置文件
MENU
    local option=4
    [ "${ENABLE_SS:-false}" = "true" ] && { echo "$option) 重置 SS 端口"; MENU_MAP[$option]="reset_ss"; option=$((option+1)); }
    [ "${ENABLE_HY2:-false}" = "true" ] && { echo "$option) 重置 HY2 端口"; MENU_MAP[$option]="reset_hy2"; option=$((option+1)); }
    [ "${ENABLE_TUIC:-false}" = "true" ] && { echo "$option) 重置 TUIC 端口"; MENU_MAP[$option]="reset_tuic"; option=$((option+1)); }
    [ "${ENABLE_REALITY:-false}" = "true" ] && { echo "$option) 重置 Reality 端口"; MENU_MAP[$option]="reset_reality"; option=$((option+1)); }
    [ "${ENABLE_VMESS:-false}" = "true" ] && { echo "$option) 重置 VMess 端口"; MENU_MAP[$option]="reset_vmess"; option=$((option+1)); }
    [ "${ENABLE_TROJAN:-false}" = "true" ] && { echo "$option) 重置 Trojan 端口"; MENU_MAP[$option]="reset_trojan"; option=$((option+1)); }
    [ "${ENABLE_ANYTLS:-false}" = "true" ] && { echo "$option) 重置 AnyTLS 端口"; MENU_MAP[$option]="reset_anytls"; option=$((option+1)); }
    MENU_MAP[option]="start";     echo "$option) 启动服务"; option=$((option+1))
    MENU_MAP[option]="stop";      echo "$option) 停止服务"; option=$((option+1))
    MENU_MAP[option]="restart";   echo "$option) 重启服务"; option=$((option+1))
    MENU_MAP[option]="status";    echo "$option) 查看状态"; option=$((option+1))
    MENU_MAP[option]="update";    echo "$option) 更新 sing-box"; option=$((option+1))
    MENU_MAP[option]="add_ss";      echo "$option) 新增 SS 节点"; option=$((option+1))
    MENU_MAP[option]="add_hy2";     echo "$option) 新增 Hysteria2 节点"; option=$((option+1))
    MENU_MAP[option]="add_tuic";    echo "$option) 新增 TUIC 节点"; option=$((option+1))
    MENU_MAP[option]="add_reality"; echo "$option) 新增 VLESS Reality 节点"; option=$((option+1))
    MENU_MAP[option]="add_vmess";   echo "$option) 新增 VMess 节点"; option=$((option+1))
    MENU_MAP[option]="add_trojan";  echo "$option) 新增 Trojan 节点"; option=$((option+1))
    MENU_MAP[option]="add_anytls"; echo "$option) 新增 AnyTLS 节点"; option=$((option+1))
    MENU_MAP[option]="uninstall"; echo "$option) 卸载 sing-box-deploy"
    echo "0) 退出"
    echo "=========================="
}

declare -A MENU_MAP=()
MENU_MAP[1]="view_uri"; MENU_MAP[2]="view_config"; MENU_MAP[3]="edit_config"

while true; do
    show_menu
    echo -n "请输入选项: "
    read -r opt
    [ "$opt" = "0" ] && exit 0
    case "${MENU_MAP[$opt]:-}" in
        view_uri) generate_uris ;;
        view_config) view_config ;;
        edit_config) edit_config ;;
        reset_ss) reset_ss_port ;;
        reset_hy2) reset_hy2_port ;;
        reset_tuic) reset_tuic_port ;;
        reset_reality) reset_reality_port ;;
        reset_vmess) reset_vmess_port ;;
        reset_trojan) reset_trojan_port ;;
        reset_anytls) reset_anytls_port ;;
        start) service_start && ok "已启动" ;;
        stop) service_stop && ok "已停止" ;;
        restart) service_restart && ok "已重启" ;;
        status) service_status ;;
        update) update_singbox ;;
        add_ss) add_ss_node ;;
        add_hy2) add_hy2_node ;;
        add_tuic) add_tuic_node ;;
        add_reality) add_reality_node ;;
        add_vmess) add_vmess_node ;;
        add_trojan) add_trojan_node ;;
        add_anytls) add_anytls_node ;;
        uninstall) uninstall_all; exit 0 ;;
        *) warn "无效选项: $opt" ;;
    esac
    echo ""
done