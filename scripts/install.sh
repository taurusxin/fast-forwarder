#!/usr/bin/env bash
set -Eeuo pipefail

# ---------- 基本配置 ----------

APP_VERSION=0.1.3
REPOSITORY=taurusxin/fast-forwarder
APP=fast-forwarder
DATA_DIR=/var/lib/fast-forwarder
BIN=/usr/local/bin/fast-forwarder
SHARE_DIR=/usr/local/share/fast-forwarder
GOST_BIN="$SHARE_DIR/gost"
GOST_VERSION=3.3.0

ENTRY_SCRIPT="${BASH_SOURCE[0]:-}"
SCRIPT_DIR=""
REPO_ROOT=""
if [[ -n "$ENTRY_SCRIPT" && -f "$ENTRY_SCRIPT" ]]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "$ENTRY_SCRIPT")" && pwd)"
  REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
fi

readonly APP_VERSION REPOSITORY APP DATA_DIR BIN SHARE_DIR GOST_BIN GOST_VERSION
readonly ENTRY_SCRIPT SCRIPT_DIR REPO_ROOT

WORK_DIR=""
PACKAGE_MANAGER=""
INIT_SYSTEM=""
ARCH=""
CURRENT_LISTEN=""
WEB_HOST=""
WEB_PORT=""
COLOR_RED=""
COLOR_GREEN=""
COLOR_YELLOW=""
COLOR_BLUE=""
COLOR_CYAN=""
COLOR_BOLD=""
COLOR_DIM=""
COLOR_RESET=""

# ---------- 通用函数 ----------

cleanup() {
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf -- "$WORK_DIR"
  fi
}

init_colors() {
  if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
    COLOR_RED=$'\033[31m'
    COLOR_GREEN=$'\033[32m'
    COLOR_YELLOW=$'\033[33m'
    COLOR_BLUE=$'\033[34m'
    COLOR_CYAN=$'\033[36m'
    COLOR_BOLD=$'\033[1m'
    COLOR_DIM=$'\033[2m'
    COLOR_RESET=$'\033[0m'
  fi
}

banner() {
  local action="$1"
  printf '\n%b%s%b\n' "$COLOR_BOLD$COLOR_BLUE" "Fast Forwarder v$APP_VERSION" "$COLOR_RESET"
  printf '%b%s%b\n\n' "$COLOR_DIM" "$action · Linux $ARCH · $INIT_SYSTEM" "$COLOR_RESET"
}

step() {
  printf '%b==>%b %s\n' "$COLOR_CYAN$COLOR_BOLD" "$COLOR_RESET" "$*"
}

info() {
  printf '%b  •%b %s\n' "$COLOR_BLUE" "$COLOR_RESET" "$*"
}

success() {
  printf '%b  ✓%b %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$*"
}

warning() {
  printf '%b  !%b %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$*"
}

die() {
  printf '%b错误：%b%s\n' "$COLOR_RED$COLOR_BOLD" "$COLOR_RESET" "$*" >&2
  exit 1
}

prompt() {
  local variable_name="$1"
  local label="$2"
  local default_value="$3"
  local answer=""

  if [[ -t 0 || -t 1 ]]; then
    printf '%b%s%b（%b默认：%s%b，直接回车使用默认值）：' \
      "$COLOR_CYAN" "$label" "$COLOR_RESET" "$COLOR_GREEN" "$default_value" "$COLOR_RESET" >/dev/tty
    IFS= read -r answer </dev/tty || die "无法读取输入"
  fi
  printf -v "$variable_name" '%s' "${answer:-$default_value}"
}

confirm() {
  local label="$1"
  local answer=""

  if [[ -t 0 || -t 1 ]]; then
    printf '%b%s%b 输入 %byes%b 确认（%b默认：否%b）：' \
      "$COLOR_YELLOW" "$label" "$COLOR_RESET" "$COLOR_BOLD" "$COLOR_RESET" \
      "$COLOR_GREEN" "$COLOR_RESET" >/dev/tty
    IFS= read -r answer </dev/tty || true
  fi
  [[ "$answer" == yes ]]
}

download() {
  local url="$1"
  local destination="$2"
  curl --fail --location --retry 3 --silent --show-error "$url" --output "$destination"
}

run_quiet() {
  local description="$1"
  shift
  local log_file="$WORK_DIR/command.log"

  step "$description"
  if "$@" >"$log_file" 2>&1; then
    success "${description}完成"
    return
  fi

  printf '%b%s失败，最近的输出如下：%b\n' "$COLOR_RED" "$description" "$COLOR_RESET" >&2
  tail -n 40 "$log_file" >&2 || true
  exit 1
}

verify_sha256() {
  local file="$1"
  local expected="$2"
  local actual
  actual="$(sha256sum "$file" | awk '{print $1}')"
  [[ -n "$expected" && "$actual" == "$expected" ]] || die "$(basename "$file") 校验失败"
}

# ---------- 系统环境 ----------

detect_platform() {
  [[ "$(id -u)" -eq 0 ]] || die "请使用 root 运行"
  [[ "$(uname -s)" == Linux ]] || die "仅支持 Linux"

  if command -v apk >/dev/null 2>&1; then
    PACKAGE_MANAGER=apk
    INIT_SYSTEM=openrc
  elif command -v apt-get >/dev/null 2>&1; then
    PACKAGE_MANAGER=apt
    INIT_SYSTEM=systemd
  elif command -v dnf >/dev/null 2>&1; then
    PACKAGE_MANAGER=dnf
    INIT_SYSTEM=systemd
  elif command -v yum >/dev/null 2>&1; then
    PACKAGE_MANAGER=yum
    INIT_SYSTEM=systemd
  else
    die "不支持当前 Linux 包管理器"
  fi

  case "$(uname -m)" in
    x86_64 | amd64) ARCH=amd64 ;;
    aarch64 | arm64) ARCH=arm64 ;;
    *) die "仅支持 amd64 和 arm64" ;;
  esac
}

install_dependencies() {
  case "$PACKAGE_MANAGER" in
    apk)
      run_quiet "安装系统依赖" apk add --no-cache bash ca-certificates curl tar iproute2
      ;;
    apt)
      run_quiet "更新软件源" apt-get update
      run_quiet "安装系统依赖" env DEBIAN_FRONTEND=noninteractive \
        apt-get install -y ca-certificates curl tar iproute2
      ;;
    dnf)
      run_quiet "安装系统依赖" dnf install -y ca-certificates curl tar iproute
      ;;
    yum)
      run_quiet "安装系统依赖" yum install -y ca-certificates curl tar iproute
      ;;
  esac
}

# ---------- 程序下载 ----------

acquire_app() {
  local local_binary="${REPO_ROOT:+$REPO_ROOT/dist/fast-forwarder_linux_$ARCH}"
  local checksum_file="$WORK_DIR/SHA256SUMS"
  local expected

  step "准备 Fast Forwarder"
  if [[ -n "$local_binary" && -f "$local_binary" ]]; then
    info "使用本地预构建文件：$local_binary"
    cp "$local_binary" "$WORK_DIR/fast-forwarder"
  elif [[ -n "$REPO_ROOT" && -f "$REPO_ROOT/go.mod" && -f "$REPO_ROOT/web/package.json" ]]; then
    command -v go >/dev/null 2>&1 || die "缺少 Go 1.27.1，请使用预构建发行包"
    command -v pnpm >/dev/null 2>&1 || die "缺少 pnpm，请使用预构建发行包"
    run_quiet "从源码构建 Fast Forwarder" bash -c \
      'cd "$1/web" && pnpm install --frozen-lockfile && pnpm build && cd "$1" && go build -o "$2" .' \
      _ "$REPO_ROOT" "$WORK_DIR/fast-forwarder"
  else
    info "下载 v$APP_VERSION Linux/$ARCH 发行文件"
    download \
      "https://github.com/$REPOSITORY/releases/download/v$APP_VERSION/fast-forwarder_linux_$ARCH" \
      "$WORK_DIR/fast-forwarder"
    download \
      "https://github.com/$REPOSITORY/releases/download/v$APP_VERSION/SHA256SUMS" \
      "$checksum_file"
    expected="$(awk -v file="fast-forwarder_linux_$ARCH" '$2 == file {print $1}' "$checksum_file")"
    verify_sha256 "$WORK_DIR/fast-forwarder" "$expected"
  fi
  chmod 755 "$WORK_DIR/fast-forwarder"
  success "Fast Forwarder 已准备并通过校验"
}

acquire_gost() {
  local archive="gost_${GOST_VERSION}_linux_${ARCH}.tar.gz"
  local archive_path="$WORK_DIR/$archive"
  local expected=""

  step "准备 GOST"
  if [[ -x "$GOST_BIN" ]] && "$GOST_BIN" -V 2>&1 | grep -q "gost v$GOST_VERSION"; then
    info "沿用已安装的 GOST v$GOST_VERSION"
    cp "$GOST_BIN" "$WORK_DIR/gost"
    success "GOST 已准备"
    return
  fi

  info "下载 GOST v$GOST_VERSION Linux/$ARCH"
  if [[ -n "$REPO_ROOT" && -f "$REPO_ROOT/dist/$archive" ]]; then
    cp "$REPO_ROOT/dist/$archive" "$archive_path"
  else
    download \
      "https://github.com/go-gost/gost/releases/download/v$GOST_VERSION/$archive" \
      "$archive_path"
  fi

  case "$ARCH" in
    amd64) expected=676fb7f78d267b6ae73df719c0c7f2b565dde7147da935cfafbc1e1da558b6d5 ;;
    arm64) expected=d03699e3f385d4ff5dad68046712adfcc7515325a064d2ab046e0bece30f8f8f ;;
  esac
  verify_sha256 "$archive_path" "$expected"
  tar -xzf "$archive_path" -C "$WORK_DIR"
  [[ -f "$WORK_DIR/gost" ]] || die "GOST 下载包缺少二进制"
  chmod 755 "$WORK_DIR/gost"
  success "GOST 已准备并通过校验"
}

# ---------- 监听配置 ----------

valid_ipv4() {
  local value="$1"
  local a b c d part
  IFS=. read -r a b c d <<<"$value"
  for part in "$a" "$b" "$c" "$d"; do
    [[ "$part" =~ ^[0-9]+$ ]] || return 1
    ((10#$part >= 0 && 10#$part <= 255)) || return 1
  done
  [[ "$value" != *.*.*.*.* ]]
}

existing_listen() {
  local service_file="${FAST_FORWARDER_SERVICE_FILE:-}"
  if [[ -z "$service_file" ]]; then
    if [[ "$INIT_SYSTEM" == systemd ]]; then
      service_file="/etc/systemd/system/$APP.service"
    else
      service_file="/etc/init.d/$APP"
    fi
  fi
  [[ -f "$service_file" ]] || return 0
  sed -nE 's/.*--listen[[:space:]]+([^[:space:]\"]+).*/\1/p' "$service_file"
}

random_port() {
  local value
  value="$(od -An -N2 -tu2 /dev/urandom | tr -d ' ')"
  echo $((20000 + value % 30000))
}

choose_listen() {
  local default_host=0.0.0.0
  local default_port
  default_port="$(random_port)"

  step "配置 Web 管理地址"

  CURRENT_LISTEN="$(existing_listen)"
  if [[ -n "$CURRENT_LISTEN" ]]; then
    default_host="${CURRENT_LISTEN%:*}"
    default_port="${CURRENT_LISTEN##*:}"
    info "检测到当前服务地址：$CURRENT_LISTEN，将作为本次默认值"
  else
    info "默认监听 0.0.0.0，可通过服务器 IP 访问；输入 127.0.0.1 可限制为仅本机访问"
  fi

  if [[ -n "${FAST_FORWARDER_LISTEN_HOST:-}" ]]; then
    WEB_HOST="$FAST_FORWARDER_LISTEN_HOST"
    info "使用环境变量指定的监听地址：$WEB_HOST"
  else
    prompt WEB_HOST "Web 管理监听地址" "$default_host"
  fi
  if [[ -n "${FAST_FORWARDER_LISTEN_PORT:-}" ]]; then
    WEB_PORT="$FAST_FORWARDER_LISTEN_PORT"
    info "使用环境变量指定的管理端口：$WEB_PORT"
  else
    prompt WEB_PORT "Web 管理端口" "$default_port"
  fi

  valid_ipv4 "$WEB_HOST" || die "管理监听地址必须是有效的 IPv4 地址"
  [[ "$WEB_PORT" =~ ^[0-9]+$ ]] || die "端口必须是数字"
  ((WEB_PORT >= 1 && WEB_PORT <= 65535)) || die "端口超出范围"

  if [[ "$CURRENT_LISTEN" != "$WEB_HOST:$WEB_PORT" ]]; then
    if [[ -z "$CURRENT_LISTEN" || "${CURRENT_LISTEN##*:}" != "$WEB_PORT" ]]; then
      ss -H -ltn "sport = :$WEB_PORT" | grep -q . && die "端口 $WEB_PORT 已被占用"
    fi
  fi
  success "Web 管理地址已确定：$WEB_HOST:$WEB_PORT"
  return 0
}

public_ipv4() {
  local address url
  for url in \
    https://api.ipify.org \
    https://ifconfig.me/ip \
    https://icanhazip.com; do
    address="$(
      curl --ipv4 --fail --silent --show-error --connect-timeout 3 --max-time 6 \
        "$url" 2>/dev/null | tr -d '[:space:]' || true
    )"
    if valid_ipv4 "$address"; then
      printf '%s' "$address"
      return 0
    fi
  done
  return 0
}

local_ipv4() {
  local address
  address="$(
    ip -4 route get 1.1.1.1 2>/dev/null \
      | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}' || true
  )"
  if valid_ipv4 "$address"; then
    printf '%s' "$address"
  fi
  return 0
}

# ---------- 服务管理 ----------

stop_service() {
  if [[ "$INIT_SYSTEM" == systemd ]]; then
    systemctl stop "$APP" 2>/dev/null || true
  else
    rc-service "$APP" stop 2>/dev/null || true
  fi
}

install_files() {
  step "安装程序文件"
  install -d -m 700 "$DATA_DIR"
  install -d -m 755 "$SHARE_DIR"
  install -m 755 "$WORK_DIR/fast-forwarder" "$BIN"
  install -m 755 "$WORK_DIR/gost" "$GOST_BIN"

  if [[ -n "$ENTRY_SCRIPT" && -f "$ENTRY_SCRIPT" ]]; then
    install -m 755 "$ENTRY_SCRIPT" "$SHARE_DIR/install.sh"
  else
    download \
      "https://github.com/$REPOSITORY/releases/download/v$APP_VERSION/install.sh" \
      "$SHARE_DIR/install.sh"
    chmod 755 "$SHARE_DIR/install.sh"
  fi
  success "程序文件已安装到 $BIN"
}

install_systemd() {
  cat >"/etc/systemd/system/$APP.service" <<SERVICE
[Unit]
Description=Fast Forwarder and GOST
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$BIN --data-dir $DATA_DIR --listen $WEB_HOST:$WEB_PORT --gost $GOST_BIN serve
WorkingDirectory=$DATA_DIR
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=$DATA_DIR

[Install]
WantedBy=multi-user.target
SERVICE
  systemctl daemon-reload
  systemctl enable --now "$APP"
}

install_openrc() {
  cat >"/etc/init.d/$APP" <<SERVICE
#!/sbin/openrc-run
name="Fast Forwarder"
command="$BIN"
command_args="--data-dir $DATA_DIR --listen $WEB_HOST:$WEB_PORT --gost $GOST_BIN serve"
command_background="yes"
pidfile="/run/$APP.pid"
depend() { need net; }
SERVICE
  chmod 755 "/etc/init.d/$APP"
  rc-update add "$APP" default
  rc-service "$APP" start
}

install_service() {
  step "创建并启动系统服务"
  if [[ "$INIT_SYSTEM" == systemd ]]; then
    install_systemd
  else
    install_openrc
  fi
  success "系统服务已启动，并已设置为开机自动运行"
}

uninstall_app() {
  banner "卸载"
  step "停止服务并移除程序文件"
  stop_service
  if [[ "$INIT_SYSTEM" == systemd ]]; then
    systemctl disable "$APP" 2>/dev/null || true
    rm -f "/etc/systemd/system/$APP.service"
    systemctl daemon-reload
  else
    rc-update del "$APP" default 2>/dev/null || true
    rm -f "/etc/init.d/$APP"
  fi
  rm -f "$BIN"
  rm -rf "$SHARE_DIR"
  success "服务与程序文件已移除"
  if confirm "是否同时删除数据库和全部规则（$DATA_DIR）？"; then
    rm -rf "$DATA_DIR"
    success "数据库与配置目录已删除"
  else
    info "数据库与配置仍保留在 $DATA_DIR"
  fi
  printf '\n%b卸载完成。%b\n' "$COLOR_GREEN$COLOR_BOLD" "$COLOR_RESET"
}

# ---------- 主流程 ----------

show_result() {
  local public_ip=""
  local private_ip=""

  printf '\n%b安装完成%b\n' "$COLOR_GREEN$COLOR_BOLD" "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_DIM" "────────────────────────────────────────" "$COLOR_RESET"
  printf 'Fast Forwarder：v%s\n' "$APP_VERSION"
  printf '监听地址：%s:%s\n' "$WEB_HOST" "$WEB_PORT"
  if [[ "$WEB_HOST" == 0.0.0.0 ]]; then
    public_ip="$(public_ipv4)"
    private_ip="$(local_ipv4)"
    if [[ -n "$public_ip" ]]; then
      printf '%b公网访问：%bhttp://%s:%s\n' "$COLOR_CYAN$COLOR_BOLD" "$COLOR_RESET" "$public_ip" "$WEB_PORT"
    else
      printf '%b公网访问：%bhttp://<服务器公网 IP>:%s\n' "$COLOR_CYAN$COLOR_BOLD" "$COLOR_RESET" "$WEB_PORT"
    fi
    if [[ -n "$private_ip" && "$private_ip" != "$public_ip" ]]; then
      printf '内网访问：http://%s:%s\n' "$private_ip" "$WEB_PORT"
    fi
    warning "如无法访问，请在云服务器安全组或防火墙中放行 TCP 端口 $WEB_PORT"
  elif [[ "$WEB_HOST" == 127.0.0.1 ]]; then
    printf '本机访问：http://127.0.0.1:%s\n' "$WEB_PORT"
    info "远程访问可使用 SSH 隧道：ssh -L $WEB_PORT:127.0.0.1:$WEB_PORT root@<服务器 IP>"
  else
    printf '%b管理页面：%bhttp://%s:%s\n' "$COLOR_CYAN$COLOR_BOLD" "$COLOR_RESET" "$WEB_HOST" "$WEB_PORT"
  fi
  printf '数据目录：%s\n' "$DATA_DIR"
  printf '%b%s%b\n' "$COLOR_DIM" "────────────────────────────────────────" "$COLOR_RESET"
  printf '管理命令：%bfast-forwarder%b\n' "$COLOR_BOLD" "$COLOR_RESET"
  printf '卸载命令：%bbash %s/install.sh uninstall%b\n\n' "$COLOR_BOLD" "$SHARE_DIR" "$COLOR_RESET"
}

install_app() {
  WORK_DIR="$(mktemp -d)"
  banner "安装 / 更新"
  info "系统环境：$PACKAGE_MANAGER · $INIT_SYSTEM · $ARCH"
  install_dependencies
  acquire_app
  acquire_gost
  choose_listen
  stop_service
  install_files
  install_service
  show_result
}

main() {
  local action="${1:-install}"
  detect_platform
  case "$action" in
    install) install_app ;;
    uninstall) uninstall_app ;;
    *) die "用法：bash install.sh [install|uninstall]" ;;
  esac
}

trap cleanup EXIT
trap 'exit 130' HUP INT TERM
init_colors
main "$@"
