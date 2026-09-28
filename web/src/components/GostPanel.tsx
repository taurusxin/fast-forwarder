import { Alert, Button, Card, Descriptions, Spin, Tag } from '@arco-design/web-react'
import type { GostInfo } from '../types'

type Props = {
  info: GostInfo | null
  loading: boolean
  onRefresh: () => void
}

export function GostPanel({ info, loading, onRefresh }: Props) {
  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between gap-4">
        <div><h1 className="text-2xl font-semibold text-slate-900">GOST 信息</h1><p className="mt-1 text-sm text-slate-500">查看当前运行状态和安装信息</p></div>
        <Button onClick={onRefresh} loading={loading}>刷新</Button>
      </div>
      <Card>
        {loading && !info ? <div className="py-12 text-center"><Spin /></div> : info ? <>
          {info.error && <Alert className="mb-5" type="error" content={info.error} />}
          <Descriptions column={1} data={[
            { label: '运行状态', value: <Tag color={info.running ? 'green' : 'red'}>{info.running ? '运行中' : '未运行'}</Tag> },
            { label: '版本', value: info.version },
            { label: '程序路径', value: <code className="break-all text-sm">{info.binary}</code> },
            { label: '配置文件', value: <code className="break-all text-sm">{info.config}</code> },
          ]} />
        </> : <p className="py-8 text-center text-slate-500">尚未加载 GOST 信息</p>}
      </Card>
    </div>
  )
}
