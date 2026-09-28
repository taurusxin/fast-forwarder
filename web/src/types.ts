export type Hop = {
  Type: 'http' | 'socks5'
  Address: string
  Username: string
  Password: string
}

export type Rule = {
  ID: string
  Name: string
  Type: 'tcp' | 'http' | 'socks5'
  ListenHost: string
  ListenPort: number
  Target: string
  Username: string
  Password: string
  Hops: Hop[]
  Enabled: boolean
}

export type Status = {
  initialized: boolean
  gostRunning: boolean
  gostError: string
  listen: string
}

export type Profile = { username: string }
export type GostInfo = { version: string; binary: string; config: string; running: boolean; error: string }
export type Section = 'forwarding' | 'proxy' | 'gost'

export const emptyRule = (): Rule => ({
  ID: '', Name: '', Type: 'tcp', ListenHost: '0.0.0.0',
  ListenPort: 0, Target: '', Username: '', Password: '',
  Hops: [], Enabled: true,
})
