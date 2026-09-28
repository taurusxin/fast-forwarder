import type { GostInfo, Profile, Rule, Status } from '../types'

export class ApiError extends Error {
  status: number
  constructor(message: string, status: number) {
    super(message)
    this.name = 'ApiError'
    this.status = status
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  let response: Response
  try {
    response = await fetch(path, {
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json' },
      ...init,
    })
  } catch {
    throw new ApiError('无法连接服务器，请检查服务状态或网络连接', 0)
  }
  const body = await response.json().catch(() => null)
  if (!response.ok) {
    const message = typeof body?.error === 'string' ? body.error : '请求失败（HTTP ' + response.status + '）'
    throw new ApiError(message, response.status)
  }
  return body as T
}

export const api = {
  status: () => request<Status>('/api/status'),
  login: (username: string, password: string) =>
    request('/api/login', { method: 'POST', body: JSON.stringify({ Username: username, Password: password }) }),
  setup: (username: string, password: string) =>
    request('/api/setup', { method: 'POST', body: JSON.stringify({ Username: username, Password: password }) }),
  logout: () => request('/api/logout', { method: 'POST' }),
  profile: () => request<Profile>('/api/me'),
  updateProfile: (username: string, currentPassword: string, newPassword: string) =>
    request<Profile>('/api/me', { method: 'PUT', body: JSON.stringify({ Username: username, CurrentPassword: currentPassword, NewPassword: newPassword }) }),
  gost: () => request<GostInfo>('/api/gost'),
  rules: async () => (await request<Rule[]>('/api/rules')).map(rule => ({ ...rule, Hops: rule.Hops || [] })),
  saveRule: (rule: Rule) => request<Rule>('/api/rules' + (rule.ID ? '/' + rule.ID : ''), {
    method: rule.ID ? 'PUT' : 'POST', body: JSON.stringify(rule),
  }),
  deleteRule: (id: string) => request('/api/rules/' + id, { method: 'DELETE' }),
  checkPort: (host: string, port: number) =>
    request('/api/ports/check?host=' + encodeURIComponent(host) + '&port=' + port),
}
