#!/usr/bin/env bash

ff_valid_ipv4() {
  local value="$1"
  local a b c d part
  IFS=. read -r a b c d <<<"$value"
  for part in "$a" "$b" "$c" "$d"; do
    [[ "$part" =~ ^[0-9]+$ ]] || return 1
    ((10#$part >= 0 && 10#$part <= 255)) || return 1
  done
  [[ "$value" != *.*.*.*.* ]]
}

ff_existing_listen() {
  local service_file="${FAST_FORWARDER_SERVICE_FILE:-}"
  if [[ -z "$service_file" ]]; then
    if [[ "$FF_INIT_SYSTEM" == systemd ]]; then
      service_file="/etc/systemd/system/$FF_APP.service"
    else
      service_file="/etc/init.d/$FF_APP"
    fi
  fi
  [[ -f "$service_file" ]] || return 0
  sed -nE 's/.*--listen[[:space:]]+([^[:space:]\"]+).*/\1/p' "$service_file"
}

ff_random_port() {
  local value
  value="$(od -An -N2 -tu2 /dev/urandom | tr -d ' ')"
  echo $((20000 + value % 30000))
}

ff_choose_listen() {
  local default_host=0.0.0.0
  local default_port
  default_port="$(ff_random_port)"

  FF_CURRENT_LISTEN="$(ff_existing_listen)"
  if [[ -n "$FF_CURRENT_LISTEN" ]]; then
    default_host="${FF_CURRENT_LISTEN%:*}"
    default_port="${FF_CURRENT_LISTEN##*:}"
  fi

  if [[ -n "${FAST_FORWARDER_LISTEN_HOST:-}" ]]; then
    FF_WEB_HOST="$FAST_FORWARDER_LISTEN_HOST"
  else
    ff_prompt FF_WEB_HOST "Web 管理监听地址" "$default_host"
  fi
  if [[ -n "${FAST_FORWARDER_LISTEN_PORT:-}" ]]; then
    FF_WEB_PORT="$FAST_FORWARDER_LISTEN_PORT"
  else
    ff_prompt FF_WEB_PORT "Web 管理端口" "$default_port"
  fi

  ff_valid_ipv4 "$FF_WEB_HOST" || ff_die "管理监听地址必须是有效的 IPv4 地址"
  [[ "$FF_WEB_PORT" =~ ^[0-9]+$ ]] || ff_die "端口必须是数字"
  ((FF_WEB_PORT >= 1 && FF_WEB_PORT <= 65535)) || ff_die "端口超出范围"

  if [[ "$FF_CURRENT_LISTEN" != "$FF_WEB_HOST:$FF_WEB_PORT" ]]; then
    if [[ -z "$FF_CURRENT_LISTEN" || "${FF_CURRENT_LISTEN##*:}" != "$FF_WEB_PORT" ]]; then
      ss -H -ltn "sport = :$FF_WEB_PORT" | grep -q . && ff_die "端口 $FF_WEB_PORT 已被占用"
    fi
  fi
  return 0
}
