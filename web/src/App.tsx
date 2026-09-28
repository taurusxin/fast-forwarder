import { useCallback, useEffect, useState } from 'react'
import { Alert, Button, Message, Modal } from '@arco-design/web-react'
import '@arco-design/web-react/dist/css/arco.css'
import { ApiError, api } from './api/client'
import { AuthPage } from './components/AuthPage'
import { Dashboard } from './components/Dashboard'
import { ProfileModal } from './components/ProfileModal'
import { RuleEditor } from './components/RuleEditor'
import { emptyRule } from './types'
import type { GostInfo, Rule, Section, Status } from './types'

function App() {
  const [status, setStatus] = useState<Status | null>(null)
  const [authorized, setAuthorized] = useState(false)
  const [rules, setRules] = useState<Rule[]>([])
  const [username, setUsername] = useState('')
  const [section, setSection] = useState<Section>('forwarding')
  const [gostInfo, setGostInfo] = useState<GostInfo | null>(null)
  const [gostLoading, setGostLoading] = useState(false)
  const [editor, setEditor] = useState<Rule | null>(null)
  const [profileOpen, setProfileOpen] = useState(false)
  const [busy, setBusy] = useState(false)
  const [saving, setSaving] = useState(false)
  const [profileSaving, setProfileSaving] = useState(false)
  const [error, setError] = useState('')
  const [authError, setAuthError] = useState('')
  const [editorError, setEditorError] = useState('')
  const [profileError, setProfileError] = useState('')

  const showError = (cause: unknown) => {
    const message = cause instanceof Error ? cause.message : '请求失败'
    if (cause instanceof ApiError && cause.status === 401) {
      setAuthorized(false)
      setAuthError('登录已过期，请重新登录')
    } else setError(message)
  }
  const refresh = useCallback(async (): Promise<boolean> => {
    try {
      const nextStatus = await api.status()
      setStatus(nextStatus)
      if (!nextStatus.initialized) return true
      try {
        const [items, profile] = await Promise.all([api.rules(), api.profile()])
        setRules(items || [])
        setUsername(profile.username)
        setAuthorized(true)
        setError('')
        return true
      } catch (cause) {
        if (cause instanceof ApiError && cause.status === 401) {
          if (authorized) setAuthError('登录已过期，请重新登录')
          setAuthorized(false)
        } else {
          const message = cause instanceof Error ? cause.message : '读取配置失败'
          if (authorized) setError(message)
          else setAuthError(message)
        }
        return false
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : '无法连接服务器')
      return false
    }
  }, [authorized])
  useEffect(() => {
    let active = true
    queueMicrotask(() => { if (active) void refresh() })
    return () => { active = false }
  }, [refresh])

  const authenticate = async (name: string, password: string): Promise<boolean> => {
    setBusy(true)
    setAuthError('')
    try {
      if (status?.initialized) await api.login(name, password)
      else await api.setup(name, password)
      if (!await refresh()) return false
      Message.success(status?.initialized ? '登录成功' : '管理员账号已创建')
      return true
    } catch (cause) {
      setAuthError(cause instanceof Error ? cause.message : '登录失败')
      return false
    } finally { setBusy(false) }
  }
  const loadGost = async () => {
    setGostLoading(true)
    try { setGostInfo(await api.gost()); setError('') }
    catch (cause) { showError(cause) }
    finally { setGostLoading(false) }
  }
  const changeSection = (next: Section) => {
    setSection(next)
    setError('')
    if (next === 'gost') void loadGost()
  }
  const saveRule = async () => {
    if (!editor) return
    setEditorError('')
    if (!editor.Name.trim()) { setEditorError('请输入规则名称'); return }
    if (!editor.ListenPort || editor.ListenPort < 1 || editor.ListenPort > 65535) { setEditorError('请输入有效监听端口'); return }
    if (editor.Type === 'tcp' && !editor.Target.trim()) { setEditorError('请输入目标地址'); return }
    setSaving(true)
    try {
      await api.saveRule(editor)
      setEditor(null)
      Message.success('规则已保存，GOST 已重新加载')
      await refresh()
      if (section === 'gost') await loadGost()
    } catch (cause) {
      setEditorError(cause instanceof Error ? cause.message : '保存失败')
      if (cause instanceof ApiError && cause.status === 401) showError(cause)
    } finally { setSaving(false) }
  }
  const removeRule = (rule: Rule) => Modal.confirm({
    title: '删除规则',
    content: '确定删除“' + rule.Name + '”？保存后 GOST 会立即重新加载。',
    onOk: async () => {
      try {
        await api.deleteRule(rule.ID)
        Message.success('规则已删除')
        await refresh()
      } catch (cause) { showError(cause) }
    },
  })
  const saveProfile = async (name: string, currentPassword: string, newPassword: string) => {
    setProfileError('')
    setProfileSaving(true)
    try {
      const profile = await api.updateProfile(name, currentPassword, newPassword)
      setUsername(profile.username)
      setProfileOpen(false)
      Message.success('用户信息已更新')
    } catch (cause) {
      setProfileError(cause instanceof Error ? cause.message : '保存失败')
      if (cause instanceof ApiError && cause.status === 401) showError(cause)
    } finally { setProfileSaving(false) }
  }
  const logout = async () => {
    try { await api.logout(); setAuthorized(false); setAuthError('') }
    catch (cause) { showError(cause) }
  }
  if (!status) return <div className="flex min-h-screen flex-col items-center justify-center gap-4 bg-slate-50 p-6">
    {error ? <><Alert type="error" content={error} /><Button onClick={() => void refresh()}>重试</Button></> : '正在加载 Fast Forwarder…'}
  </div>
  if (!status.initialized || !authorized) return <AuthPage initialized={status.initialized} busy={busy} error={authError} onSubmit={authenticate} />
  return <>
    <Dashboard status={status} rules={rules} username={username} section={section} error={error}
      gostInfo={gostInfo} gostLoading={gostLoading}
      onSectionChange={changeSection}
      onCreate={() => { setEditorError(''); setEditor({ ...emptyRule(), Type: section === 'forwarding' ? 'tcp' : 'http' }) }}
      onEdit={rule => { setEditorError(''); setEditor({ ...rule, Hops: rule.Hops || [] }) }}
      onRemove={removeRule} onProfile={() => { setProfileError(''); setProfileOpen(true) }}
      onLogout={() => void logout()} onRefresh={() => { if (section === 'gost') void loadGost(); else void refresh() }} onRefreshGost={() => void loadGost()}
      onDismissError={() => setError('')} />
    {editor && <RuleEditor key={editor.ID || 'new'} rule={editor} saving={saving} error={editorError}
      onChange={rule => { setEditorError(''); setEditor(rule) }}
      onSave={() => void saveRule()} onCancel={() => setEditor(null)} />}
    {profileOpen && <ProfileModal username={username} saving={profileSaving} error={profileError}
      onSave={(name, current, next) => void saveProfile(name, current, next)}
      onCancel={() => setProfileOpen(false)} />}
  </>
}
export default App
