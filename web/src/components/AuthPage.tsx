import { useState } from 'react'
import { Alert, Button, Card, Input, Typography } from '@arco-design/web-react'

type Props = {
  initialized: boolean
  busy: boolean
  error: string
  onSubmit: (username: string, password: string) => Promise<boolean>
}

export function AuthPage({ initialized, busy, error, onSubmit }: Props) {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const submit = async () => {
    if (await onSubmit(username, password)) setPassword('')
  }
  return (
    <main className="flex min-h-screen items-center justify-center bg-gradient-to-br from-blue-50 to-slate-50 px-4">
      <Card className="w-full max-w-md shadow-xl">
        <div className="p-4 sm:p-6">
          <div className="mb-5 flex h-12 w-12 items-center justify-center rounded-xl bg-blue-600 font-bold tracking-tight text-white">FF</div>
          <Typography.Title heading={3}>Fast Forwarder</Typography.Title>
          <p className="mb-6 text-sm text-slate-500">{initialized ? '登录管理控制台' : '首次使用，请创建管理员账号'}</p>
          {error && <Alert className="mb-4" type="error" content={error} />}
          <label className="mb-2 block font-medium">用户名</label>
          <Input value={username} onChange={setUsername} placeholder="至少 3 位" autoComplete="username" />
          <label className="mb-2 mt-5 block font-medium">密码</label>
          <Input.Password value={password} onChange={setPassword}
            placeholder={initialized ? '输入密码' : '至少 12 位'}
            autoComplete={initialized ? 'current-password' : 'new-password'}
            onPressEnter={() => void submit()} />
          <Button className="mt-6" type="primary" long loading={busy} onClick={() => void submit()}>
            {initialized ? '登录' : '创建管理员'}
          </Button>
        </div>
      </Card>
    </main>
  )
}
