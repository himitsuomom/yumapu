export type Role = 'system' | 'user' | 'assistant'

export interface Message {
  role: Role
  content: string
}

export interface ChatRequest {
  messages: Message[]
  mode?: 'coach' | 'generate' | 'debug' | 'refactor' | 'test'
  codeOnly?: boolean
}

const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost:8000'

export async function chat(req: ChatRequest): Promise<string> {
  const res = await fetch(`${API_BASE}/api/chat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(req),
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}`)
  const data = await res.json()
  return data.reply as string
}
