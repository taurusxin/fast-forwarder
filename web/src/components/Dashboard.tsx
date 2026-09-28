import { Alert, Button, Card, Dropdown, Menu, Space, Tag } from '@arco-design/web-react'
import type { GostInfo, Rule, Section, Status } from '../types'
import { GostPanel } from './GostPanel'
import { RulesTable } from './RulesTable'

type Props = {
  status: Status
  rules: Rule[]
  username: string
  section: Section
  error: string
  gostInfo: GostInfo | null
  gostLoading: boolean
  onSectionChange: (section: Section) => void
  onCreate: () => void
  onEdit: (rule: Rule) => void
  onRemove: (rule: Rule) => void
  onProfile: () => void
  onLogout: () => void
  onRefresh: () => void
  onRefreshGost: () => void
  onDismissError: () => void
}

export function Dashboard(props: Props) {
  const { status, rules, section, username, error, gostInfo, gostLoading } = props
  const filtered = rules.filter(rule => section === 'forwarding' ? rule.Type === 'tcp' : rule.Type !== 'tcp')
  const title = section === 'forwarding' ? 'TCP 转发' : 'HTTP / SOCKS5 代理'
  const menu = <Menu onClickMenuItem={key => {
    if (key === 'profile') props.onProfile()
    if (key === 'logout') props.onLogout()
  }}>
    <Menu.Item key="profile">修改用户信息</Menu.Item>
    <Menu.Item key="logout">退出登录</Menu.Item>
  </Menu>
  return (
    <div className="flex min-h-screen bg-slate-50 text-slate-800">
      <aside className="flex w-18 shrink-0 flex-col border-r border-slate-200 bg-white sm:w-56">
        <div className="flex h-17 items-center gap-3 border-b border-slate-100 px-4 sm:px-5">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-blue-600 text-xs font-bold text-white">FF</span>
          <span className="hidden font-semibold sm:block">Fast Forwarder</span>
        </div>
        <Menu className="mt-4" selectedKeys={[section]} onClickMenuItem={key => props.onSectionChange(key as Section)}>
          <Menu.Item key="forwarding"><span className="flex items-center gap-3"><span className="w-5 text-center">⇄</span><span className="hidden sm:inline">TCP 转发</span></span></Menu.Item>
          <Menu.Item key="proxy"><span className="flex items-center gap-3"><span className="w-5 text-center">◎</span><span className="hidden sm:inline">HTTP / SOCKS5 代理</span></span></Menu.Item>
          <Menu.Item key="gost"><span className="flex items-center gap-3"><span className="w-5 text-center">G</span><span className="hidden sm:inline">GOST 信息</span></span></Menu.Item>
        </Menu>
        <div className="mt-auto border-t border-slate-100 px-4 py-5 text-xs text-slate-400"><span className="hidden sm:inline">配置保存后立即应用</span></div>
      </aside>
      <div className="min-w-0 flex-1">
        <header className="flex h-17 items-center justify-between border-b border-slate-200 bg-white px-4 sm:px-8">
          <div className="text-sm text-slate-500">管理控制台</div>
          <Space>
            <Tag color={status.gostRunning ? 'green' : 'red'}>{status.gostRunning ? 'GOST 运行中' : 'GOST 未运行'}</Tag>
            <Dropdown trigger="click" droplist={menu} position="br">
              <Button type="text">{username || '管理员'} ▾</Button>
            </Dropdown>
          </Space>
        </header>
        <main className="mx-auto max-w-6xl space-y-6 p-4 sm:p-8">
          {error && <Alert type="error" content={error} closable onClose={props.onDismissError}
            action={<Button size="small" onClick={props.onRefresh}>重试</Button>} />}
          {section === 'gost' ? <GostPanel info={gostInfo} loading={gostLoading} onRefresh={props.onRefreshGost} /> : <>
            <div className="flex items-start justify-between gap-4">
              <div><h1 className="text-2xl font-semibold text-slate-900">{title}</h1>
                <p className="mt-1 text-sm text-slate-500">{section === 'forwarding' ? '将本地 TCP 端口转发到目标服务，可串联多个上游代理' : '配置 HTTP 或 SOCKS5 代理服务及上游链路'}</p>
              </div>
              <Button type="primary" onClick={props.onCreate}>新建规则</Button>
            </div>
            <div className="grid gap-4 sm:grid-cols-3">
              <Card><p className="text-sm text-slate-500">规则总数</p><strong className="mt-1 block text-2xl">{filtered.length}</strong></Card>
              <Card><p className="text-sm text-slate-500">已启用</p><strong className="mt-1 block text-2xl">{filtered.filter(rule => rule.Enabled).length}</strong></Card>
              <Card><p className="text-sm text-slate-500">链路节点</p><strong className="mt-1 block text-2xl">{filtered.reduce((total, rule) => total + rule.Hops.length, 0)}</strong></Card>
            </div>
            <RulesTable rules={filtered} onEdit={props.onEdit} onRemove={props.onRemove} />
          </>}
        </main>
      </div>
    </div>
  )
}
