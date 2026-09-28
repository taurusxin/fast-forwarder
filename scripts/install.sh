#!/usr/bin/env bash
set -Eeuo pipefail

APP_VERSION=0.1.1
REPOSITORY=taurusxin/fast-forwarder
INSTALLER_ARCHIVE=fast-forwarder_installer.tar.gz

readonly APP_VERSION REPOSITORY INSTALLER_ARCHIVE
readonly ENTRY_SCRIPT="${BASH_SOURCE[0]:-}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null && pwd)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." 2>/dev/null && pwd)"

MODULE_DIR="$SCRIPT_DIR/install"
BOOTSTRAP_DIR=""

bootstrap_cleanup() {
  if [[ -n "$BOOTSTRAP_DIR" && -d "$BOOTSTRAP_DIR" ]]; then
    rm -rf -- "$BOOTSTRAP_DIR"
  fi
}

load_modules() {
  local module
  local -a modules=(common platform artifacts config service main)

  for module in "${modules[@]}"; do
    if [[ ! -f "$MODULE_DIR/$module.bash" ]]; then
      command -v curl >/dev/null 2>&1 || { echo "缺少 curl，无法下载安装模块" >&2; exit 1; }
      command -v tar >/dev/null 2>&1 || { echo "缺少 tar，无法解压安装模块" >&2; exit 1; }
      BOOTSTRAP_DIR="$(mktemp -d)"
      curl --fail --location --retry 3 --show-error \
        "https://github.com/$REPOSITORY/releases/download/v$APP_VERSION/$INSTALLER_ARCHIVE" \
        --output "$BOOTSTRAP_DIR/$INSTALLER_ARCHIVE"
      tar -xzf "$BOOTSTRAP_DIR/$INSTALLER_ARCHIVE" -C "$BOOTSTRAP_DIR"
      MODULE_DIR="$BOOTSTRAP_DIR/install"
      break
    fi
  done

  for module in "${modules[@]}"; do
    [[ -f "$MODULE_DIR/$module.bash" ]] || { echo "安装模块缺失：$module.bash" >&2; exit 1; }
    # shellcheck source=/dev/null
    source "$MODULE_DIR/$module.bash"
  done
}

trap bootstrap_cleanup EXIT HUP INT TERM
load_modules
trap 'ff_cleanup; bootstrap_cleanup' EXIT
trap 'exit 130' HUP INT TERM
ff_main "$@"
