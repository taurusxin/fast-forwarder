# Fast Forwarder

[![Release](https://img.shields.io/github/v/release/taurusxin/fast-forwarder?label=Release)](https://github.com/taurusxin/fast-forwarder/releases)
[![Build](https://github.com/taurusxin/fast-forwarder/actions/workflows/release.yml/badge.svg)](https://github.com/taurusxin/fast-forwarder/actions/workflows/release.yml)
![Linux](https://img.shields.io/badge/Linux-amd64%20%7C%20arm64-2ea44f)

在浏览器里管理 TCP 转发和 HTTP / SOCKS5 代理。添加规则、检查端口、保存配置，Fast Forwarder 会立即应用更改；也可以为转发规则设置多级代理链。

## 一键安装

在 Linux 服务器上运行：

```sh
curl -fsSL https://github.com/taurusxin/fast-forwarder/releases/download/v0.1.0/install.sh -o /tmp/fast-forwarder-install.sh && sudo sh /tmp/fast-forwarder-install.sh
```

安装脚本会下载并安装 Fast Forwarder 与 GOST，支持 **Debian / Ubuntu、CentOS 系和 Alpine** 的 amd64、arm64 服务器。安装时按提示选择 Web 管理地址和端口；直接回车会使用本机地址和随机端口。完成后，打开脚本显示的地址，首次访问时创建管理员账号。

默认只允许从服务器本机访问管理页面。如需从自己的电脑打开，可使用 SSH 端口转发；将下面的端口替换为安装时显示的端口：

```sh
ssh -L 44930:127.0.0.1:44930 root@你的服务器地址
```

然后在浏览器打开 `http://127.0.0.1:44930`。

## 能做什么

- **TCP 转发**：把一个监听端口转发到目标服务，支持多级上游代理链。
- **HTTP / SOCKS5 代理**：单独管理代理规则，可设置账号密码和上游链路。
- **保存即生效**：保存前检查监听端口；保存或删除后立即应用配置。
- **管理账号**：首次访问创建管理员，之后可在右上角修改用户名和密码。
- **查看 GOST**：在左侧菜单查看版本、运行状态和安装信息。

## 日常管理

在服务器上执行 `fast-forwarder` 可打开交互菜单，查看配置与状态、重启服务、安装更新或卸载。卸载时会询问是否同时删除已有数据。

如需重新运行安装脚本，仍可使用上方命令；已有管理地址和规则会保留。

更多下载文件和版本记录见 [GitHub Releases](https://github.com/taurusxin/fast-forwarder/releases)。
