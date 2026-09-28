import { useState } from 'react'
import { Alert, Button, Card, Input, InputNumber, Message, Modal, Select, Space, Switch } from '@arco-design/web-react'
import { api } from '../api/client'
import type { Hop, Rule } from '../types'

type Props = {
  rule: Rule | null
  saving: boolean
  error: string
  onChange: (rule: Rule) => void
  onSave: () => void
  onCancel: () => void
}

export function RuleEditor({ rule, saving, error, onChange, onSave, onCancel }: Props) {
  const [portError, setPortError] = useState('')
  if (!rule) return null
  const patch = (change: Partial<Rule>) => onChange({ ...rule, ...change })
  const patchHop = (index: number, change: Partial<Hop>) =>
    patch({ Hops: rule.Hops.map((hop, i) => i === index ? { ...hop, ...change } : hop) })
  const checkPort = async () => {
    setPortError('')
    try {
      await api.checkPort(rule.ListenHost, rule.ListenPort)
      Message.success('端口当前可用')
    } catch (cause) { setPortError((cause as Error).message) }
  }
  const field = 'mb-4 min-w-0'
  const label = 'mb-2 block font-medium'
  return (
    <Modal title={rule.ID ? '编辑规则' : '新建规则'} visible onCancel={onCancel}
      onOk={onSave} confirmLoading={saving} okText="保存并应用" style={{ width: 720 }} unmountOnExit>
      <div className="max-h-[65vh] space-y-1 overflow-y-auto px-1">
        {(error || portError) && <Alert className="mb-4" type="error" content={error || portError} />}
        <div className={field}>
          <label className={label}>规则名称</label>
          <Input value={rule.Name} onChange={Name => patch({ Name })} placeholder="例如：业务服务转发" />
        </div>
        <div className="grid gap-x-4 sm:grid-cols-2">
          <div className={field}>
            <label className={label}>类型</label>
            {rule.Type === 'tcp'
              ? <Input value="TCP 转发" disabled />
              : <Select value={rule.Type} onChange={Type => patch({ Type })}
                  options={[{ label: 'HTTP 代理', value: 'http' }, { label: 'SOCKS5 代理', value: 'socks5' }]} />}
          </div>
          <div className={field}>
            <label className={label}>状态</label>
            <div className="flex h-8 items-center gap-3"><Switch checked={rule.Enabled} onChange={Enabled => patch({ Enabled })} /> {rule.Enabled ? '启用' : '停用'}</div>
          </div>
          <div className={field}>
            <label className={label}>监听 IP</label>
            <Input value={rule.ListenHost} onChange={ListenHost => patch({ ListenHost })} placeholder="0.0.0.0" />
          </div>
          <div className={field}>
            <label className={label}>监听端口</label>
            <Space>
              <InputNumber min={1} max={65535} value={rule.ListenPort || undefined}
                onChange={ListenPort => patch({ ListenPort: Number(ListenPort) })} placeholder="1–65535" />
              <Button onClick={() => void checkPort()}>检查端口</Button>
            </Space>
          </div>
        </div>
        {rule.Type === 'tcp' && <div className={field}>
          <label className={label}>目标地址</label>
          <Input value={rule.Target} onChange={Target => patch({ Target })} placeholder="example.com:443" />
        </div>}
        {rule.Type !== 'tcp' && <div className="grid gap-x-4 sm:grid-cols-2">
          <div className={field}><label className={label}>代理用户名（可选）</label><Input value={rule.Username} onChange={Username => patch({ Username })} /></div>
          <div className={field}><label className={label}>代理密码（可选）</label><Input.Password value={rule.Password} onChange={Password => patch({ Password })} /></div>
        </div>}
        <div className="mb-4 mt-2 flex items-center justify-between border-t border-slate-200 pt-5">
          <div><strong>多级转发链</strong><p className="mt-1 text-sm text-slate-500">按顺序连接 HTTP 或 SOCKS5 上游节点</p></div>
          <Button size="small" onClick={() => patch({ Hops: [...rule.Hops, { Type: 'socks5', Address: '', Username: '', Password: '' }] })}>添加节点</Button>
        </div>
        {rule.Hops.map((hop, index) =>
          <Card key={index} size="small" className="mb-3" title={'第 ' + (index + 1) + ' 级'}
            extra={<Button size="mini" status="danger" type="text" onClick={() => patch({ Hops: rule.Hops.filter((_, i) => i !== index) })}>移除</Button>}>
            <div className="grid gap-x-4 sm:grid-cols-2">
              <div className={field}><label className={label}>协议</label><Select value={hop.Type} onChange={Type => patchHop(index, { Type })} options={[{ label: 'HTTP', value: 'http' }, { label: 'SOCKS5', value: 'socks5' }]} /></div>
              <div className={field}><label className={label}>节点地址</label><Input value={hop.Address} onChange={Address => patchHop(index, { Address })} placeholder="proxy.example.com:1080" /></div>
              <div className={field}><label className={label}>用户名（可选）</label><Input value={hop.Username} onChange={Username => patchHop(index, { Username })} /></div>
              <div className={field}><label className={label}>密码（可选）</label><Input.Password value={hop.Password} onChange={Password => patchHop(index, { Password })} /></div>
            </div>
          </Card>)}
      </div>
    </Modal>
  )
}
