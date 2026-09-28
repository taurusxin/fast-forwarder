#!/usr/bin/env bash

ff_detect_platform() {
  [[ "$(id -u)" -eq 0 ]] || ff_die "请使用 root 运行"
  [[ "$(uname -s)" == Linux ]] || ff_die "仅支持 Linux"

  if command -v apk >/dev/null 2>&1; then
    FF_PACKAGE_MANAGER=apk
    FF_INIT_SYSTEM=openrc
  elif command -v apt-get >/dev/null 2>&1; then
    FF_PACKAGE_MANAGER=apt
    FF_INIT_SYSTEM=systemd
  elif command -v dnf >/dev/null 2>&1; then
    FF_PACKAGE_MANAGER=dnf
    FF_INIT_SYSTEM=systemd
  elif command -v yum >/dev/null 2>&1; then
    FF_PACKAGE_MANAGER=yum
    FF_INIT_SYSTEM=systemd
  else
    ff_die "不支持当前 Linux 包管理器"
  fi

  case "$(uname -m)" in
    x86_64 | amd64) FF_ARCH=amd64 ;;
    aarch64 | arm64) FF_ARCH=arm64 ;;
    *) ff_die "仅支持 amd64 和 arm64" ;;
  esac
}

ff_install_dependencies() {
  case "$FF_PACKAGE_MANAGER" in
    apk)
      apk add --no-cache bash ca-certificates curl tar iproute2
      ;;
    apt)
      apt-get update
      env DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl tar iproute2
      ;;
    dnf)
      dnf install -y ca-certificates curl tar iproute
      ;;
    yum)
      yum install -y ca-certificates curl tar iproute
      ;;
  esac
}
