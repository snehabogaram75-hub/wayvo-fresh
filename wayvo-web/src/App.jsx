import { useState } from 'react'
import './style.css'

const API = '';

function App() {
  const [message, setMessage] = useState('')
  const [messages, setMessages] = useState([])
  const [historyOpen, setHistoryOpen] = useState(false)
  const [sending, setSending] = useState(false)

  const suggestions = [
    ['☀️', 'Plan my day'],
    ['🎓', 'Help me learn'],
    ['💡', 'Give me ideas'],
    ['🧩', 'Solve a problem'],
  ]

  async function sendMessage(text = message) {
    const value = text.trim()
    if (!value || sending) return

    setMessages(prev => [...prev, { role: 'user', content: value }])
    setMessage('')
    setSending(true)

    try {
      const res = await fetch(`${API}/api/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ message: value }),
      })

      const data = await res.json()

      setMessages(prev => [
        ...prev,
        {
          role: 'WAYVO',
          content: data.reply || data.response || data.message || 'WAYVO could not respond.',
        },
      ])
    } catch {
      setMessages(prev => [
        ...prev,
        {
          role: 'WAYVO',
          content: 'Could not connect to WAYVO backend.',
        },
      ])
    } finally {
      setSending(false)
    }
  }

  return (
    <div className="app">

      <aside className={`sidebar ${historyOpen ? 'mobile-open' : ''}`}>
        <div className="side-top">
          <div className="logo">WAYVO</div>

          <button
            className="new-chat"
            onClick={() => {
              setMessages([])
              setHistoryOpen(false)
            }}
          >
            <span>＋</span> New Chat
          </button>

          <div className="chat-title">CHATS</div>
        </div>

        <div className="chat-history">
          {messages.length === 0 ? (
            <div className="empty-history">
              Your conversations will appear here.
            </div>
          ) : (
            <div className="history-item">
              {messages.find(m => m.role === 'user')?.content || 'Chat'}
            </div>
          )}
        </div>
      </aside>

      {historyOpen && (
        <div
          className="mobile-overlay"
          onClick={() => setHistoryOpen(false)}
        />
      )}

      <main className="workspace">

        <header className="topbar">
          <button
            className="menu"
            onClick={() => setHistoryOpen(true)}
          >
            ☰
          </button>

          <div className="workspace-title">
            <span className="desktop-title">Personal AI Workspace</span>
            <span className="mobile-title">WAYVO</span>
          </div>

          <div className="top-logo">WAYVO</div>
        </header>

        <section className="chat-area">

          {messages.length === 0 ? (
            <div className="welcome">
              <h1>What can we get done?</h1>
              <p>Tell WAYVO what you are working on.</p>

              <div className="suggestions">
                {suggestions.map(([icon, text]) => (
                  <button
                    key={text}
                    className="suggestion"
                    onClick={() => sendMessage(text)}
                  >
                    <span>{icon}</span>
                    <span>{text}</span>
                  </button>
                ))}
              </div>
            </div>
          ) : (
            <div className="messages">
              {messages.map((m, i) => (
                <div
                  key={i}
                  className={`message ${m.role === 'user' ? 'user' : 'wayvo'}`}
                >
                  {m.role === 'WAYVO' && (
                    <div className="wayvo-avatar">••</div>
                  )}

                  <div className="message-content">
                    <div className="message-role">
                      {m.role === 'user' ? 'You' : 'WAYVO'}
                    </div>
                    <div className="message-text">{m.content}</div>
                  </div>
                </div>
              ))}

              {sending && (
                <div className="message wayvo">
                  <div className="wayvo-avatar">••</div>
                  <div className="message-content">
                    <div className="message-role">WAYVO</div>
                    <div className="thinking">Thinking…</div>
                  </div>
                </div>
              )}
            </div>
          )}

        </section>

        <div className="input-area">

          <button className="round-button" title="Attachments">
            ＋
          </button>

          <div className="composer">

            <textarea
              value={message}
              onChange={e => setMessage(e.target.value)}
              onKeyDown={e => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault()
                  sendMessage()
                }
              }}
              placeholder="What do you want to get done?"
              rows="1"
            />

            <button className="mic-button" title="Voice">
              🎤
            </button>

          </div>

          <button
            className="send-button"
            onClick={() => sendMessage()}
            disabled={sending}
          >
            {message.trim() ? '↑' : '◉'}
          </button>

        </div>

      </main>
    </div>
  )
}

export default App
