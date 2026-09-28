import { Button, Card, Space, Table, Tag } from '@arco-design/web-react'
import type { Rule } from '../types'

type Props = {
  rules: Rule[]
  onEdit: (rule: Rule) => void
  onRemove: (rule: Rule) => void
}

export function RulesTable({ rules, onEdit, onRemove }: Props) {
  return (
    <Card title="规则列表">
      <Table rowKey="ID" data={rules} pagination={false} scroll={{ x: 800 }} columns={[
        { title: '名称', dataIndex: 'Name' },
        { title: '类型', render: (_, rule: Rule) => <Tag color="arcoblue">{rule.Type.toUpperCase()}</Tag> },
        { title: '监听地址', render: (_, rule: Rule) => rule.ListenHost + ':' + rule.ListenPort },
        { title: '目标 / 链路', render: (_, rule: Rule) => rule.Type === 'tcp' ? rule.Target : '代理服务' },
        { title: '链路层数', render: (_, rule: Rule) => rule.Hops.length || '直连' },
        { title: '状态', render: (_, rule: Rule) => <Tag color={rule.Enabled ? 'green' : 'gray'}>{rule.Enabled ? '启用' : '停用'}</Tag> },
        { title: '操作', render: (_, rule: Rule) => <Space>
          <Button size="small" type="text" onClick={() => onEdit(rule)}>编辑</Button>
          <Button size="small" type="text" status="danger" onClick={() => onRemove(rule)}>删除</Button>
        </Space> },
      ]} />
    </Card>
  )
}
