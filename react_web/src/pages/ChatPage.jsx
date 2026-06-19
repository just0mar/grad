import { useState, useEffect, useRef } from 'react';
import { useParams } from 'react-router-dom';
import TopBar from '../components/TopBar';
import PageTransition from '../components/PageTransition';
import LoadingSpinner from '../components/LoadingSpinner';
import useTheme from '../hooks/useTheme';
import useAuth from '../hooks/useAuth';
import { getMessages, sendMessage, markAsRead } from '../services/messagingService';
import { Send } from 'lucide-react';

export default function ChatPage() {
  const { isDark } = useTheme();
  const { id: conversationId } = useParams();
  const { currentUser } = useAuth();
  const [messages, setMessages] = useState([]);
  const [loading, setLoading] = useState(false);
  const [text, setText] = useState('');
  const [sending, setSending] = useState(false);
  const bottomRef = useRef(null);

  useEffect(() => {
    if (!conversationId) return;
    let cancelled = false;
    const fetch = async () => {
      setLoading(true);
      try {
        const data = await getMessages(conversationId);
        if (!cancelled) setMessages((data || []).reverse());
        await markAsRead(conversationId);
      } catch {}
      finally { if (!cancelled) setLoading(false); }
    };
    fetch();
    return () => { cancelled = true; };
  }, [conversationId]);

  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages]);

  const handleSend = async () => {
    if (!text.trim() || sending) return;
    setSending(true);
    try {
      const msg = await sendMessage(conversationId, text.trim());
      setMessages(prev => [...prev, msg]);
      setText('');
    } catch {}
    finally { setSending(false); }
  };

  const handleKey = (e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleSend(); } };

  return (
    <PageTransition className="flex-1 flex flex-col">
      <TopBar title="Chat" showBack />
      <div className="flex-1 overflow-y-auto px-4 py-2 space-y-2">
        {loading && <div className="flex justify-center py-8"><LoadingSpinner /></div>}
        {messages.map((msg) => {
          const isMine = msg.senderUserId === currentUser?.userId;
          return (
            <div key={msg.messageId} className={`flex ${isMine ? 'justify-end' : 'justify-start'}`}>
              <div className={`max-w-[75%] p-3 rounded-2xl text-sm ${isMine ? 'bg-primary text-white rounded-br-md' : isDark ? 'bg-surface-dark text-white rounded-bl-md' : 'bg-gray-100 text-black rounded-bl-md'}`}>
                {!isMine && <p className="text-xs font-semibold mb-1 opacity-70">{msg.senderName}</p>}
                <p>{msg.content}</p>
                <p className={`text-[10px] mt-1 ${isMine ? 'text-white/60' : isDark ? 'text-white/40' : 'text-gray-400'}`}>
                  {new Date(msg.sentAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </p>
              </div>
            </div>
          );
        })}
        <div ref={bottomRef} />
      </div>
      <div className={`sticky bottom-0 px-4 py-3 border-t ${isDark ? 'bg-surface-darkest border-white/10' : 'bg-white border-gray-200'}`}>
        <div className="flex gap-2 max-w-3xl mx-auto">
          <input value={text} onChange={(e) => setText(e.target.value)} onKeyDown={handleKey}
            placeholder="Type a message..." id="input-message"
            className={`flex-1 px-4 py-2.5 rounded-full text-sm border ${isDark ? 'bg-surface-dark border-white/10 text-white placeholder:text-white/30' : 'bg-gray-50 border-gray-200 text-black placeholder:text-gray-400'}`} />
          <button onClick={handleSend} disabled={sending || !text.trim()}
            className="p-2.5 rounded-full bg-primary text-white disabled:opacity-50 transition-opacity" id="btn-send">
            <Send size={18} />
          </button>
        </div>
      </div>
    </PageTransition>
  );
}
