import { useState } from 'react'
import { Alert, Input, Modal } from '@arco-design/web-react'

type Props = {
  username: string
  saving: boolean
  error: string
  onCancel: () => void
  onSave: (username: string, currentPassword: string, newPassword: string) => void
}

export function ProfileModal({ username, saving, error, onCancel, onSave }: Props) {
  const [name, setName] = useState(username)
  const [currentPassword, setCurrentPassword] = useState('')
  const [newPassword, setNewPassword] = useState('')
  return (
    <Modal title="修改用户信息" visible onCancel={onCancel} onOk={() => onSave(name, currentPassword, newPassword)}
      okText="保存" confirmLoading={saving} unmountOnExit>
      <div className="space-y-5">
        {error && <Alert type="error" content={error} />}
        <div><label className="mb-2 block font-medium">用户名</label><Input value={name} onChange={setName} /></div>
        <div><label className="mb-2 block font-medium">当前密码</label><Input.Password value={currentPassword} onChange={setCurrentPassword} placeholder="用于确认身份" /></div>
        <div><label className="mb-2 block font-medium">新密码（留空则不修改）</label><Input.Password value={newPassword} onChange={setNewPassword} placeholder="至少 12 位" /></div>
      </div>
    </Modal>
  )
}
