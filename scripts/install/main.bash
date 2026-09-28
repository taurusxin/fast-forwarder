#!/usr/bin/env bash

ff_show_result() {
  echo
  echo "安装完成。"
  echo "监听地址：$FF_WEB_HOST:$FF_WEB_PORT"
  if [[ "$FF_WEB_HOST" == 0.0.0.0 ]]; then
    echo "管理页面：http://<服务器 IP>:$FF_WEB_PORT"
  else
    echo "管理页面：http://$FF_WEB_HOST:$FF_WEB_PORT"
  fi
  echo "执行 fast-forwarder 可打开交互菜单。"
}

ff_install() {
  ff_install_dependencies
  FF_WORK_DIR="$(mktemp -d)"
  ff_acquire_app
  ff_acquire_gost
  ff_choose_listen
  ff_stop_service
  ff_install_files
  ff_install_service
  ff_show_result
}

ff_main() {
  local action="${1:-install}"
  ff_detect_platform
  case "$action" in
    install) ff_install ;;
    uninstall) ff_uninstall ;;
    *) ff_die "用法：bash install.sh [install|uninstall]" ;;
  esac
}
