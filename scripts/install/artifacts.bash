#!/usr/bin/env bash

ff_download() {
  local url="$1"
  local destination="$2"
  curl --fail --location --retry 3 --show-error "$url" --output "$destination"
}

ff_verify_sha256() {
  local file="$1"
  local expected="$2"
  local actual
  actual="$(sha256sum "$file" | awk '{print $1}')"
  [[ -n "$expected" && "$actual" == "$expected" ]] || ff_die "$(basename "$file") 校验失败"
}

ff_acquire_app() {
  local local_binary="$REPO_ROOT/dist/fast-forwarder_linux_$FF_ARCH"
  local checksum_file="$FF_WORK_DIR/SHA256SUMS"
  local expected

  if [[ -f "$local_binary" ]]; then
    cp "$local_binary" "$FF_WORK_DIR/fast-forwarder"
  elif [[ -f "$REPO_ROOT/go.mod" && -f "$REPO_ROOT/web/package.json" ]]; then
    command -v go >/dev/null 2>&1 || ff_die "缺少 Go 1.27.1，请使用预构建发行包"
    command -v pnpm >/dev/null 2>&1 || ff_die "缺少 pnpm，请使用预构建发行包"
    (cd "$REPO_ROOT/web" && pnpm install --frozen-lockfile && pnpm build)
    (cd "$REPO_ROOT" && go build -o "$FF_WORK_DIR/fast-forwarder" .)
  else
    echo "下载 Fast Forwarder v$APP_VERSION ($FF_ARCH)..."
    ff_download \
      "https://github.com/$REPOSITORY/releases/download/v$APP_VERSION/fast-forwarder_linux_$FF_ARCH" \
      "$FF_WORK_DIR/fast-forwarder"
    ff_download \
      "https://github.com/$REPOSITORY/releases/download/v$APP_VERSION/SHA256SUMS" \
      "$checksum_file"
    expected="$(awk -v file="fast-forwarder_linux_$FF_ARCH" '$2 == file {print $1}' "$checksum_file")"
    ff_verify_sha256 "$FF_WORK_DIR/fast-forwarder" "$expected"
  fi
  chmod 755 "$FF_WORK_DIR/fast-forwarder"
}

ff_acquire_gost() {
  local archive="gost_${FF_GOST_VERSION}_linux_${FF_ARCH}.tar.gz"
  local archive_path="$FF_WORK_DIR/$archive"
  local expected=""

  if [[ -x "$FF_GOST_BIN" ]] && "$FF_GOST_BIN" -V 2>&1 | grep -q "gost v$FF_GOST_VERSION"; then
    echo "沿用已安装的 GOST $FF_GOST_VERSION"
    cp "$FF_GOST_BIN" "$FF_WORK_DIR/gost"
    return
  fi

  echo "下载 GOST $FF_GOST_VERSION ($FF_ARCH)..."
  if [[ -f "$REPO_ROOT/dist/$archive" ]]; then
    cp "$REPO_ROOT/dist/$archive" "$archive_path"
  else
    ff_download \
      "https://github.com/go-gost/gost/releases/download/v$FF_GOST_VERSION/$archive" \
      "$archive_path"
  fi

  case "$FF_ARCH" in
    amd64) expected=676fb7f78d267b6ae73df719c0c7f2b565dde7147da935cfafbc1e1da558b6d5 ;;
    arm64) expected=d03699e3f385d4ff5dad68046712adfcc7515325a064d2ab046e0bece30f8f8f ;;
  esac
  ff_verify_sha256 "$archive_path" "$expected"
  tar -xzf "$archive_path" -C "$FF_WORK_DIR"
  [[ -f "$FF_WORK_DIR/gost" ]] || ff_die "GOST 下载包缺少二进制"
  chmod 755 "$FF_WORK_DIR/gost"
}
