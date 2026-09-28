# Fast Forwarder Web

Arco Design + Tailwind CSS + React 管理界面。使用 pnpm 管理依赖。

- src/api/client.ts：后端请求
- src/components/：页面及规则组件
- src/styles/tailwind.css：Tailwind CSS 样式入口
- src/types.ts：数据类型
- src/App.tsx：页面状态与组件编排

开发构建：pnpm build。后端将 web/dist 嵌入 Go 二进制。
