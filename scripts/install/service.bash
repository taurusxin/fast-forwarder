#!/usr/bin/env bash

ff_stop_service() {
  if [[ "$FF_INIT_SYSTEM" == systemd ]]; then
    systemctl stop "$FF_APP" 2>/dev/null || true
  else
    rc-service "$FF_APP" stop 2>/dev/null || true
  fi
}

ff_install_files() {
  install -d -m 700 "$FF_DATA_DIR"
  install -d -m 755 "$FF_SHARE_DIR"
  install -m 755 "$FF_WORK_DIR/fast-forwarder" "$FF_BIN"
  install -m 755 "$FF_WORK_DIR/gost" "$FF_GOST_BIN"

  if [[ -n "$ENTRY_SCRIPT" && -f "$ENTRY_SCRIPT" ]]; then
    install -m 755 "$ENTRY_SCRIPT" "$FF_SHARE_DIR/install.sh"
  else
    ff_download \
      "https://github.com/$REPOSITORY/releases/download/v$APP_VERSION/install.sh" \
      "$FF_SHARE_DIR/install.sh"
    chmod 755 "$FF_SHARE_DIR/install.sh"
  fi
}

ff_install_systemd() {
  cat >"/etc/systemd/system/$FF_APP.service" <<SERVICE
[Unit]
Description=Fast Forwarder and GOST
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$FF_BIN --data-dir $FF_DATA_DIR --listen $FF_WEB_HOST:$FF_WEB_PORT --gost $FF_GOST_BIN serve
WorkingDirectory=$FF_DATA_DIR
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=$FF_DATA_DIR

[Install]
WantedBy=multi-user.target
SERVICE
  systemctl daemon-reload
  systemctl enable --now "$FF_APP"
}

ff_install_openrc() {
  cat >"/etc/init.d/$FF_APP" <<SERVICE
#!/sbin/openrc-run
name="Fast Forwarder"
command="$FF_BIN"
command_args="--data-dir $FF_DATA_DIR --listen $FF_WEB_HOST:$FF_WEB_PORT --gost $FF_GOST_BIN serve"
command_background="yes"
pidfile="/run/$FF_APP.pid"
depend() { need net; }
SERVICE
  chmod 755 "/etc/init.d/$FF_APP"
  rc-update add "$FF_APP" default
  rc-service "$FF_APP" start
}

ff_install_service() {
  if [[ "$FF_INIT_SYSTEM" == systemd ]]; then
    ff_install_systemd
  else
    ff_install_openrc
  fi
}

ff_uninstall() {
  ff_stop_service
  if [[ "$FF_INIT_SYSTEM" == systemd ]]; then
    systemctl disable "$FF_APP" 2>/dev/null || true
    rm -f "/etc/systemd/system/$FF_APP.service"
    systemctl daemon-reload
  else
    rc-update del "$FF_APP" default 2>/dev/null || true
    rm -f "/etc/init.d/$FF_APP"
  fi
  rm -f "$FF_BIN"
  rm -rf "$FF_SHARE_DIR"
  if ff_confirm "删除数据库及配置目录 $FF_DATA_DIR？"; then
    rm -rf "$FF_DATA_DIR"
  fi
  echo "卸载完成"
}
