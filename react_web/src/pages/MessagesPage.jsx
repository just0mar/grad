import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import TopBar from '../components/TopBar';
import PageTransition from '../components/PageTransition';
import EmptyState from '../components/EmptyState';
import LoadingSpinner from '../components/LoadingSpinner';
import Avatar from '../components/Avatar';
import useTheme from '../hooks/useTheme';
import useAuth from '../hooks/useAuth';
import { getConversations } from '../services/messagingService';
import { MessageSquare } from 'lucide-react';

export default function MessagesPage() {
  const { isDark } = useTheme();
  const navigate = useNavigate();
  const { currentUser } = useAuth();
  const [conversations, setConversations] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let cancelled = false;
    const fetch = async () => {
      setLoading(true);
      try {
        const data = await getConversations();
        if (!cancelled) setConversations(data || []);
      } catch { if (!cancelled) setConversations([]); }
      finally { if (!cancelled) setLoading(false); }
    };
    fetch();
    return () => { cancelled = true; };
  }, []);

  const getDisplayName = (conv) => {
    if (conv.name) return conv.name;
    const others = conv.participants?.filter(p => p.userId !== currentUser?.userId) || [];
    return others.map(p => p.name).join(', ') || 'Conversation';
  };

  return (
    <PageTransition className="flex-1">
      <TopBar title="Messages" />
      <div className="px-4 md:px-6 lg:px-8 pb-24 lg:pb-8 max-w-3xl mx-auto w-full">
        {loading && <div className="flex justify-center py-8"><LoadingSpinner /></div>}
        {!loading && conversations.length === 0 && (
          <EmptyState icon={MessageSquare} title="No conversations" subtitle="Start a conversation from a team member's profile" />
        )}
        {!loading && conversations.length > 0 && (
          <div className="space-y-1 mt-2">
            {conversations.map((conv) => (
              <button key={conv.conversationId} onClick={() => navigate(`/app/messages/${conv.conversationId}`)}
                className={`w-full flex items-center gap-3 p-3 rounded-card transition-colors text-left ${isDark ? 'hover:bg-white/5' : 'hover:bg-gray-50'}`}>
                <Avatar alt={getDisplayName(conv)} size="md" />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <p className={`font-semibold text-sm truncate ${isDark ? 'text-white' : 'text-black'}`}>{getDisplayName(conv)}</p>
                    {conv.lastMessage && <span className={`text-xs flex-shrink-0 ${isDark ? 'text-white/40' : 'text-gray-400'}`}>{new Date(conv.lastMessage.sentAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>}
                  </div>
                  {conv.lastMessage && <p className={`text-xs truncate ${isDark ? 'text-white/50' : 'text-gray-500'}`}>{conv.lastMessage.content}</p>}
                </div>
                {conv.unreadCount > 0 && (
                  <span className="bg-primary text-white text-xs font-bold rounded-full w-5 h-5 flex items-center justify-center">{conv.unreadCount}</span>
                )}
              </button>
            ))}
          </div>
        )}
      </div>
    </PageTransition>
  );
}
