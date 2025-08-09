import { useState } from 'react'
import type { Message } from './api'
import { chat } from './api'

const modes = ['coach','generate','debug','refactor','test'] as const

type Mode = typeof modes[number]

export default function App() {
  const [messages, setMessages] = useState<Message[]>([])
  const [input, setInput] = useState('')
  const [mode, setMode] = useState<Mode>('coach')
  const [codeOnly, setCodeOnly] = useState(false)
  const [loading, setLoading] = useState(false)

  const send = async () => {
    const text = input.trim()
    if (!text || loading) return
    const nextMessages = [...messages, { role: 'user', content: text }]
    setMessages(nextMessages)
    setInput('')
    setLoading(true)
    try {
      const reply = await chat({ messages: nextMessages, mode, codeOnly })
      setMessages([...nextMessages, { role: 'assistant', content: reply }])
    } catch (e: any) {
      setMessages([...nextMessages, { role: 'assistant', content: `Error: ${e.message}` }])
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      <header className="sticky top-0 z-10 border-b bg-white/80 backdrop-blur">
        <div className="mx-auto max-w-5xl px-4 py-3 flex items-center gap-3">
          <h1 className="font-semibold text-lg">PromptSmith Chat</h1>
          <select
            value={mode}
            onChange={(e) => setMode(e.target.value as Mode)}
            className="ml-auto rounded border px-2 py-1"
            title="Mode"
          >
            {modes.map(m => <option key={m} value={m}>{m}</option>)}
          </select>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={codeOnly} onChange={e=>setCodeOnly(e.target.checked)} />
            code-only
          </label>
        </div>
      </header>

      <main className="mx-auto max-w-5xl px-4 py-6">
        <div className="rounded-2xl border bg-white p-4 h-[70vh] overflow-auto space-y-4">
          {messages.length === 0 && (
            <div className="text-sm text-slate-500">
              Ask for help writing a prompt, generating code, debugging, refactoring, or writing tests.
            </div>
          )}
          {messages.map((m, i) => (
            <div key={i} className={m.role === 'user' ? 'text-right' : ''}>
              <div className={`inline-block max-w-[90%] whitespace-pre-wrap rounded-xl px-3 py-2 text-sm ${m.role==='user' ? 'bg-blue-600 text-white' : 'bg-slate-100'}`}>
                {m.content}
              </div>
            </div>
          ))}
          {loading && <div className="text-sm text-slate-500">Thinking…</div>}
        </div>

        <div className="mt-4 flex gap-2">
          <textarea
            value={input}
            onChange={e=>setInput(e.target.value)}
            onKeyDown={e=>{ if(e.key==='Enter' && !e.shiftKey){ e.preventDefault(); send(); }}}
            placeholder="Type your message… (Shift+Enter = new line)"
            className="flex-1 rounded-xl border bg-white p-3 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            rows={3}
          />
          <button
            onClick={send}
            disabled={loading}
            className="h-[3.75rem] min-w-24 self-end rounded-xl bg-blue-600 px-4 font-medium text-white shadow hover:bg-blue-700 disabled:opacity-50"
          >
            Send
          </button>
        </div>
      </main>
    </div>
  )
}
