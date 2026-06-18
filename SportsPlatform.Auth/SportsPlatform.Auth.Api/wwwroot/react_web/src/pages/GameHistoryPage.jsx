import { useState, useEffect } from 'react';
import TopBar from '../components/TopBar';
import PageTransition from '../components/PageTransition';
import EmptyState from '../components/EmptyState';
import LoadingSpinner from '../components/LoadingSpinner';
import Modal from '../components/Modal';
import useTheme from '../hooks/useTheme';
import useClub from '../hooks/useClub';
import { getMatchHistory, getMatchStats } from '../services/statsService';
import { History, Eye } from 'lucide-react';

export default function GameHistoryPage() {
  const { isDark } = useTheme();
  const { activeClubId, activeTeamId } = useClub();
  const [matches, setMatches] = useState([]);
  const [detail, setDetail] = useState(null);
  const [loading, setLoading] = useState(false);
  const [detailLoading, setDetailLoading] = useState(false);

  useEffect(() => {
    if (!activeClubId || !activeTeamId) { setMatches([]); return; }
    let cancelled = false;
    const fetch = async () => {
      setLoading(true);
      try {
        const data = await getMatchHistory(activeClubId, activeTeamId);
        if (!cancelled) setMatches(data || []);
      } catch { if (!cancelled) setMatches([]); }
      finally { if (!cancelled) setLoading(false); }
    };
    fetch();
    return () => { cancelled = true; };
  }, [activeClubId, activeTeamId]);

  const openDetail = async (eventId) => {
    setDetailLoading(true);
    setDetail(null);
    try {
      setDetail(await getMatchStats(activeClubId, activeTeamId, eventId));
    } finally {
      setDetailLoading(false);
    }
  };

  return (
    <PageTransition className="flex-1">
      <TopBar title="Game History" showBack />
      <div className="px-4 md:px-6 lg:px-8 pb-24 lg:pb-8 max-w-7xl mx-auto w-full">
        {loading && <div className="flex justify-center py-8"><LoadingSpinner /></div>}
        {!loading && matches.length === 0 && <EmptyState icon={History} title="No games yet" subtitle="Game and session stats will appear here when recorded" />}
        {!loading && matches.length > 0 && (
          <div className="space-y-3 mt-2">
            {matches.map((match) => (
              <button key={match.matchStatsId} onClick={() => openDetail(match.eventId)} className={`w-full p-4 rounded-card shadow-sm text-left ${isDark ? 'bg-surface-dark hover:bg-white/5' : 'bg-white hover:bg-gray-50'}`}>
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <h3 className={`font-semibold ${isDark ? 'text-white' : 'text-black'}`}>{match.eventTitle}</h3>
                    <p className={`text-sm mt-1 ${isDark ? 'text-white/50' : 'text-gray-500'}`}>
                      {match.eventType} - {new Date(match.eventStartAt).toLocaleDateString()} {match.opponentName ? `- vs ${match.opponentName}` : ''}
                    </p>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className={`font-bold ${isDark ? 'text-white' : 'text-black'}`}>{match.teamScore ?? '-'}-{match.opponentScore ?? '-'}</span>
                    <Eye size={18} className="text-primary" />
                  </div>
                </div>
              </button>
            ))}
          </div>
        )}
      </div>

      <Modal isOpen={!!detail || detailLoading} onClose={() => setDetail(null)} title={detail?.eventTitle || 'Stats detail'}>
        {detailLoading && <div className="flex justify-center py-8"><LoadingSpinner /></div>}
        {!detailLoading && detail && (
          <div className="space-y-3">
            <div className="grid grid-cols-2 gap-3">
              <Metric label="Score" value={`${detail.teamScore ?? '-'}-${detail.opponentScore ?? '-'}`} isDark={isDark} />
              <Metric label="Result" value={detail.result || '-'} isDark={isDark} />
              <Metric label="Shots" value={`${detail.shotsOnTarget ?? 0}/${detail.totalShots ?? 0}`} isDark={isDark} />
              <Metric label="Pass %" value={detail.passAccuracy != null ? `${Number(detail.passAccuracy).toFixed(1)}%` : '-'} isDark={isDark} />
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className={isDark ? 'text-white/50' : 'text-gray-500'}>
                  <tr className={isDark ? 'border-b border-white/10' : 'border-b border-gray-100'}>
                    {['Player', 'Min', 'G', 'A', 'Shots', 'Rating'].map((h) => <th key={h} className="text-left p-3 font-medium">{h}</th>)}
                  </tr>
                </thead>
                <tbody>
                  {detail.playerStats?.map((p) => (
                    <tr key={p.playerMatchStatsId} className={isDark ? 'border-b border-white/5' : 'border-b border-gray-50'}>
                      <td className={`p-3 font-semibold ${isDark ? 'text-white' : 'text-black'}`}>{p.playerName}</td>
                      <td className="p-3">{p.minutesPlayed ?? '-'}</td>
                      <td className="p-3">{p.goals ?? 0}</td>
                      <td className="p-3">{p.assists ?? 0}</td>
                      <td className="p-3">{p.shotsOnTarget ?? 0}/{p.totalShots ?? 0}</td>
                      <td className="p-3">{p.rating != null ? Number(p.rating).toFixed(1) : '-'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </Modal>
    </PageTransition>
  );
}

function Metric({ label, value, isDark }) {
  return (
    <div className={`p-3 rounded-card ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
      <p className={`text-xs ${isDark ? 'text-white/40' : 'text-gray-500'}`}>{label}</p>
      <p className={`text-sm font-bold mt-1 ${isDark ? 'text-white' : 'text-black'}`}>{value}</p>
    </div>
  );
}
