#!/usr/bin/env bash

readonly FF_APP=fast-forwarder
readonly FF_DATA_DIR=/var/lib/fast-forwarder
readonly FF_BIN=/usr/local/bin/fast-forwarder
readonly FF_SHARE_DIR=/usr/local/share/fast-forwarder
readonly FF_GOST_BIN="$FF_SHARE_DIR/gost"
readonly FF_GOST_VERSION=3.3.0

FF_WORK_DIR=""
FF_PACKAGE_MANAGER=""
FF_INIT_SYSTEM=""
FF_ARCH=""
FF_CURRENT_LISTEN=""
FF_WEB_HOST=""
FF_WEB_PORT=""

ff_cleanup() {
  if [[ -n "$FF_WORK_DIR" && -d "$FF_WORK_DIR" ]]; then
    rm -rf -- "$FF_WORK_DIR"
  fi
}

ff_die() {
  echo "错误：$*" >&2
  exit 1
}

ff_prompt() {
  local variable_name="$1"
  local label="$2"
  local default_value="$3"
  local answer=""

  if [[ -t 0 || -t 1 ]]; then
    printf '%s [%s]: ' "$label" "$default_value" >/dev/tty
    IFS= read -r answer </dev/tty || ff_die "无法读取输入"
  fi
  printf -v "$variable_name" '%s' "${answer:-$default_value}"
}

ff_confirm() {
  local label="$1"
  local answer=""

  if [[ -t 0 || -t 1 ]]; then
    printf '%s 输入 yes 确认：' "$label" >/dev/tty
    IFS= read -r answer </dev/tty || true
  fi
  [[ "$answer" == yes ]]
}
