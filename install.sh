#!/bin/sh
set -eu
APP=fast-forwarder
APP_VERSION=0.1.0
DATA_DIR=/var/lib/fast-forwarder
BIN=/usr/local/bin/fast-forwarder
SHARE=/usr/local/share/fast-forwarder
GOST_BIN=/usr/local/share/fast-forwarder/gost
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ACTION=install
[ $# -eq 0 ] || ACTION=$1
GOST_VERSION=3.3.0
[ "$(id -u)" -eq 0 ] || { echo "请使用 root 运行" >&2; exit 1; }
[ "$(uname -s)" = Linux ] || { echo "仅支持 Linux" >&2; exit 1; }
if command -v apk >/dev/null 2>&1; then PM=apk; INIT=openrc
elif command -v apt-get >/dev/null 2>&1; then PM=apt; INIT=systemd
elif command -v dnf >/dev/null 2>&1; then PM=dnf; INIT=systemd
elif command -v yum >/dev/null 2>&1; then PM=yum; INIT=systemd
else echo "不支持的 Linux 包管理器" >&2; exit 1
fi
case "$(uname -m)" in
 x86_64|amd64) ARCH=amd64 ;;
 aarch64|arm64) ARCH=arm64 ;;
 *) echo "仅支持 amd64 和 arm64" >&2; exit 1 ;;
esac
stop_service() {
 if [ "$INIT" = systemd ]; then systemctl stop "$APP" 2>/dev/null || true
 else rc-service "$APP" stop 2>/dev/null || true; fi
}
uninstall() {
 stop_service
 if [ "$INIT" = systemd ]; then
  systemctl disable "$APP" 2>/dev/null || true
  rm -f "/etc/systemd/system/$APP.service"
  systemctl daemon-reload
 else
  rc-update del "$APP" default 2>/dev/null || true
  rm -f "/etc/init.d/$APP"
 fi
 rm -f "$BIN"
 rm -rf "$SHARE"
 printf '删除数据库及配置目录 %s？输入 yes 确认：' "$DATA_DIR"
 read -r answer
 [ "$answer" != yes ] || rm -rf "$DATA_DIR"
 echo "卸载完成"
}
if [ "$ACTION" = uninstall ]; then uninstall; exit 0; fi
[ "$ACTION" = install ] || { echo "用法: sh install.sh [install|uninstall]" >&2; exit 1; }
case "$PM" in
 apk) apk add --no-cache ca-certificates curl tar iproute2 ;;
 apt) apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl tar iproute2 ;;
 dnf) dnf install -y ca-certificates curl tar iproute ;;
 yum) yum install -y ca-certificates curl tar iproute ;;
esac
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
if [ -f "$ROOT_DIR/dist/fast-forwarder_linux_$ARCH" ]; then
 cp "$ROOT_DIR/dist/fast-forwarder_linux_$ARCH" "$tmp/fast-forwarder"
elif [ -f "$ROOT_DIR/go.mod" ] && [ -f "$ROOT_DIR/web/package.json" ]; then
 command -v go >/dev/null 2>&1 || { echo "缺少 Go 1.27.1，请安装 Go 或使用预构建包" >&2; exit 1; }
 command -v pnpm >/dev/null 2>&1 || { echo "缺少 pnpm，请安装 pnpm 或使用预构建包" >&2; exit 1; }
 (cd "$ROOT_DIR/web" && pnpm install --frozen-lockfile && pnpm build)
 (cd "$ROOT_DIR" && go build -o "$tmp/fast-forwarder" .)
else
 echo "下载 Fast Forwarder v$APP_VERSION ($ARCH)..."
 curl -fL --retry 3 "https://github.com/taurusxin/fast-forwarder/releases/download/v$APP_VERSION/fast-forwarder_linux_$ARCH" -o "$tmp/fast-forwarder"
 curl -fL --retry 3 "https://github.com/taurusxin/fast-forwarder/releases/download/v$APP_VERSION/SHA256SUMS" -o "$tmp/SHA256SUMS"
 expected=$(awk -v file="fast-forwarder_linux_$ARCH" '$2 == file {print $1}' "$tmp/SHA256SUMS")
 [ -n "$expected" ] || { echo "发行包缺少校验值" >&2; exit 1; }
 actual=$(sha256sum "$tmp/fast-forwarder" | cut -d ' ' -f 1)
 [ "$actual" = "$expected" ] || { echo "Fast Forwarder 下载包校验失败" >&2; exit 1; }
fi
gost_archive="gost_$GOST_VERSION"
gost_archive=$gost_archive"_linux_$ARCH.tar.gz"
gost_url="https://github.com/go-gost/gost/releases/download/v$GOST_VERSION/$gost_archive"
if [ -x "$GOST_BIN" ] && "$GOST_BIN" -V 2>&1 | grep -q "gost v$GOST_VERSION"; then
 echo "沿用已安装的 GOST $GOST_VERSION"
 cp "$GOST_BIN" "$tmp/gost"
else
 echo "下载 GOST $GOST_VERSION ($ARCH)..."
 if [ -f "$ROOT_DIR/dist/$gost_archive" ]; then
  cp "$ROOT_DIR/dist/$gost_archive" "$tmp/$gost_archive"
 else
  curl -fL --retry 3 "$gost_url" -o "$tmp/$gost_archive"
 fi
 case "$ARCH" in
  amd64) expected=676fb7f78d267b6ae73df719c0c7f2b565dde7147da935cfafbc1e1da558b6d5 ;;
  arm64) expected=d03699e3f385d4ff5dad68046712adfcc7515325a064d2ab046e0bece30f8f8f ;;
 esac
 actual=$(sha256sum "$tmp/$gost_archive" | cut -d ' ' -f 1)
 [ "$actual" = "$expected" ] || { echo "GOST 下载包校验失败" >&2; exit 1; }
 tar -xzf "$tmp/$gost_archive" -C "$tmp"
fi
[ -f "$tmp/gost" ] || { echo "GOST 下载包缺少二进制" >&2; exit 1; }
if [ -f "$DATA_DIR/fast-forwarder.db" ]; then
 current_listen=$("$tmp/fast-forwarder" --data-dir "$DATA_DIR" config)
 [ -n "$current_listen" ] || { echo "无法读取现有管理地址" >&2; exit 1; }
 web_host=$(printf '%s' "$current_listen" | rev | cut -d: -f2- | rev)
 web_port=$(printf '%s' "$current_listen" | rev | cut -d: -f1 | rev)
 echo "沿用现有管理地址：$current_listen"
else
 default_port=$(od -An -N2 -tu2 /dev/urandom | tr -d ' ')
 default_port=$((20000 + default_port % 30000))
 printf 'Web 管理监听 IP [127.0.0.1]: '
 read -r web_host
 [ -n "$web_host" ] || web_host=127.0.0.1
 case "$web_host" in *[!0-9.]*|'') echo "管理监听 IP 需为 IPv4 地址" >&2; exit 1 ;; esac
 printf '%s\n' "$web_host" | awk -F. 'NF==4 {for(i=1;i<=4;i++) if($i=="" || $i>255 || $i<0) exit 1; ok=1} END {if(!ok) exit 1}' || { echo "管理监听 IP 无效" >&2; exit 1; }
 printf 'Web 管理端口 [%s]: ' "$default_port"
 read -r web_port
 [ -n "$web_port" ] || web_port=$default_port
 case "$web_port" in *[!0-9]*|'') echo "端口必须是数字" >&2; exit 1 ;; esac
 [ "$web_port" -ge 1 ] && [ "$web_port" -le 65535 ] || { echo "端口超出范围" >&2; exit 1; }
 if ss -H -ltn "sport = :$web_port" | grep -q .; then echo "端口 $web_port 已被占用" >&2; exit 1; fi
fi
stop_service
install -d -m 700 "$DATA_DIR"
install -d -m 755 "$SHARE"
install -m 755 "$tmp/fast-forwarder" "$BIN"
install -m 755 "$tmp/gost" "$GOST_BIN"
if [ "$ROOT_DIR" != "$SHARE" ]; then
 install -m 755 "$0" "$SHARE/install.sh"
fi
if [ "$INIT" = systemd ]; then
 cat > "/etc/systemd/system/$APP.service" <<SERVICE
[Unit]
Description=Fast Forwarder and GOST
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
ExecStart=$BIN --data-dir $DATA_DIR --listen $web_host:$web_port --gost $GOST_BIN serve
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
else
 cat > "/etc/init.d/$APP" <<SERVICE
#!/sbin/openrc-run
name="Fast Forwarder"
command="$BIN"
command_args="--data-dir $DATA_DIR --listen $web_host:$web_port --gost $GOST_BIN serve"
command_background="yes"
pidfile="/run/$APP.pid"
depend() { need net; }
SERVICE
 chmod 755 "/etc/init.d/$APP"
 rc-update add "$APP" default
 rc-service "$APP" start
fi
echo "安装完成。管理地址：http://$web_host:$web_port"
echo "执行 fast-forwarder 可打开交互菜单。"
if [ "$web_host" = 127.0.0.1 ]; then echo "远程访问请使用 SSH 端口转发。"; fi
