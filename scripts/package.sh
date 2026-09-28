#!/usr/bin/env bash
set -Eeuo pipefail

readonly ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/web"
pnpm install --frozen-lockfile
pnpm lint
pnpm build
cd "$ROOT"
mkdir -p dist
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o dist/fast-forwarder_linux_amd64 .
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o dist/fast-forwarder_linux_arm64 .
