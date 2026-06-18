import { useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import TopBar from '../components/TopBar';
import PageTransition from '../components/PageTransition';
import EmptyState from '../components/EmptyState';
import LoadingSpinner from '../components/LoadingSpinner';
import Modal from '../components/Modal';
import FormInput from '../components/FormInput';
import SelectField from '../components/SelectField';
import useTheme from '../hooks/useTheme';
import useAuth from '../hooks/useAuth';
import useClub from '../hooks/useClub';
import { getTeamMembers } from '../services/teamService';
import { getTeamEvents } from '../services/eventService';
import { createStats, getMatchHistory, getMatchStats, getPlayerMatchHistory, getPlayerStats, getTeamStats, uploadStatsFile } from '../services/statsService';
import { BarChart3, Trophy, Target, Upload, ClipboardList, Users, Eye, Save, User } from 'lucide-react';
import { getRoleAccess } from '../utils/roleAccess';

const TAB_ITEMS = ['Dashboard', 'Entry', 'Upload', 'History'];
const RESULT_VALUES = ['', 'Win', 'Draw', 'Loss'];
const RESULT_LABELS = ['Not set', 'Win', 'Draw', 'Loss'];

const blankTeamForm = {
  eventId: '',
  opponentName: '',
  teamScore: '',
  opponentScore: '',
  result: '',
  venue: '',
  competitionName: '',
  possessionPercent: '',
  totalGoals: '',
  totalAssists: '',
  shotsOnTarget: '',
  totalShots: '',
  passesCompleted: '',
  passesAttempted: '',
  passAccuracy: '',
  tackles: '',
  interceptions: '',
  yellowCards: '',
  redCards: '',
  notes: '',
};

const blankPlayerStats = (player) => ({
  playerUserId: player.userId,
  playerName: player.name,
  minutesPlayed: '',
  goals: '',
  assists: '',
  shotsOnTarget: '',
  totalShots: '',
  passesCompleted: '',
  passesAttempted: '',
  passAccuracy: '',
  tackles: '',
  interceptions: '',
  yellowCards: '',
  redCards: '',
  rating: '',
  notes: '',
});

const numberOrNull = (value) => value === '' || value === null || value === undefined ? null : Number(value);

const cleanRequest = (teamForm, playerRows) => ({
  eventId: teamForm.eventId,
  opponentName: teamForm.opponentName.trim() || null,
  teamScore: numberOrNull(teamForm.teamScore),
  opponentScore: numberOrNull(teamForm.opponentScore),
  result: teamForm.result || null,
  venue: teamForm.venue.trim() || null,
  competitionName: teamForm.competitionName.trim() || null,
  possessionPercent: numberOrNull(teamForm.possessionPercent),
  totalGoals: numberOrNull(teamForm.totalGoals),
  totalAssists: numberOrNull(teamForm.totalAssists),
  shotsOnTarget: numberOrNull(teamForm.shotsOnTarget),
  totalShots: numberOrNull(teamForm.totalShots),
  passesCompleted: numberOrNull(teamForm.passesCompleted),
  passesAttempted: numberOrNull(teamForm.passesAttempted),
  passAccuracy: numberOrNull(teamForm.passAccuracy),
  tackles: numberOrNull(teamForm.tackles),
  interceptions: numberOrNull(teamForm.interceptions),
  yellowCards: numberOrNull(teamForm.yellowCards),
  redCards: numberOrNull(teamForm.redCards),
  notes: teamForm.notes.trim() || null,
  playerStats: playerRows.map((p) => ({
    playerUserId: p.playerUserId,
    minutesPlayed: numberOrNull(p.minutesPlayed),
    goals: numberOrNull(p.goals),
    assists: numberOrNull(p.assists),
    shotsOnTarget: numberOrNull(p.shotsOnTarget),
    totalShots: numberOrNull(p.totalShots),
    passesCompleted: numberOrNull(p.passesCompleted),
    passesAttempted: numberOrNull(p.passesAttempted),
    passAccuracy: numberOrNull(p.passAccuracy),
    tackles: numberOrNull(p.tackles),
    interceptions: numberOrNull(p.interceptions),
    yellowCards: numberOrNull(p.yellowCards),
    redCards: numberOrNull(p.redCards),
    rating: numberOrNull(p.rating),
    notes: p.notes?.trim() || null,
  })),
});

export default function TeamStatsPage() {
  const { isDark } = useTheme();
  const [searchParams] = useSearchParams();
  const { currentUser, isAdmin } = useAuth();
  const { activeClubId, activeTeamId, selectedTeam } = useClub();
  const access = getRoleAccess(currentUser, isAdmin);
  const isPlayerOnly = access.isPlayer;
  const canEnterStats = access.canEnterStats;
  const canBrowsePlayers = !isPlayerOnly;

  const [activeTab, setActiveTab] = useState('Dashboard');
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [teamStats, setTeamStats] = useState(null);
  const [history, setHistory] = useState([]);
  const [events, setEvents] = useState([]);
  const [players, setPlayers] = useState([]);
  const [playerAggregate, setPlayerAggregate] = useState(null);
  const [playerHistory, setPlayerHistory] = useState([]);
  const [teamForm, setTeamForm] = useState(blankTeamForm);
  const [playerRows, setPlayerRows] = useState([]);
  const [preview, setPreview] = useState(null);
  const [previewFile, setPreviewFile] = useState(null);
  const [detail, setDetail] = useState(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const visibleTabs = canEnterStats ? TAB_ITEMS : ['Dashboard', 'History'];

  useEffect(() => {
    const requestedTab = searchParams.get('tab');
    if (requestedTab && visibleTabs.includes(requestedTab)) setActiveTab(requestedTab);
  }, [searchParams, visibleTabs.join('|')]);

  const loadAll = async (cancelledRef) => {
    if (!activeClubId || !activeTeamId) return;
    setLoading(true);
    setError('');
    try {
      const [statsData, historyData, eventData, memberData, ownStats, ownHistory] = await Promise.all([
        getTeamStats(activeClubId, activeTeamId),
        getMatchHistory(activeClubId, activeTeamId),
        getTeamEvents(activeClubId, activeTeamId),
        getTeamMembers(activeClubId, activeTeamId),
        currentUser?.userId ? getPlayerStats(activeClubId, activeTeamId, currentUser.userId).catch(() => null) : null,
        currentUser?.userId ? getPlayerMatchHistory(activeClubId, activeTeamId, currentUser.userId).catch(() => []) : [],
      ]);
      if (cancelledRef?.cancelled) return;
      const roster = (memberData || []).filter((m) => m.role === 'Player');
      const statEvents = (eventData || []).filter((event) => event.eventType === 'Match' || event.eventType === 'Training');
      setTeamStats(statsData);
      setHistory(historyData || []);
      setEvents(statEvents);
      setPlayers(roster);
      setPlayerAggregate(ownStats);
      setPlayerHistory(ownHistory || []);
      setTeamForm((prev) => ({ ...prev, eventId: searchParams.get('eventId') || prev.eventId || statEvents[0]?.eventId || '' }));
      setPlayerRows(roster.map(blankPlayerStats));
    } catch (err) {
      if (!cancelledRef?.cancelled) setError(err.response?.data?.error || 'Failed to load stats');
    } finally {
      if (!cancelledRef?.cancelled) setLoading(false);
    }
  };

  useEffect(() => {
    if (!activeClubId || !activeTeamId) {
      setTeamStats(null);
      setHistory([]);
      return;
    }
    const cancelledRef = { cancelled: false };
    loadAll(cancelledRef);
    return () => { cancelledRef.cancelled = true; };
  }, [activeClubId, activeTeamId, currentUser?.userId]);

  const eventOptions = useMemo(() => events.map((event) => `${event.title} - ${event.eventType} - ${new Date(event.startAt).toLocaleDateString()}`), [events]);
  const eventValues = useMemo(() => events.map((event) => event.eventId), [events]);

  const updatePlayerRow = (index, key, value) => {
    setPlayerRows((rows) => rows.map((row, i) => i === index ? { ...row, [key]: value } : row));
  };

  const handleSaveManual = async () => {
    setError('');
    setSuccess('');
    if (!teamForm.eventId) {
      setError('Choose a match or training event first.');
      return;
    }
    setSaving(true);
    try {
      await createStats(activeClubId, activeTeamId, cleanRequest(teamForm, playerRows));
      setSuccess('Stats saved.');
      await loadAll();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to save stats');
    } finally {
      setSaving(false);
    }
  };

  const handlePreviewUpload = async (file) => {
    setError('');
    setSuccess('');
    setPreview(null);
    setPreviewFile(file);
    if (!teamForm.eventId) {
      setError('Choose the event before uploading stats.');
      return;
    }
    setUploading(true);
    try {
      const data = await uploadStatsFile(activeClubId, activeTeamId, teamForm.eventId, file);
      setPreview(data);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to parse file');
    } finally {
      setUploading(false);
    }
  };

  const handleConfirmPreview = async () => {
    if (!preview?.parsedStats) return;
    setSaving(true);
    setError('');
    setSuccess('');
    try {
      await createStats(activeClubId, activeTeamId, preview.parsedStats);
      setPreview(null);
      setPreviewFile(null);
      setSuccess('Uploaded stats saved.');
      await loadAll();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to save uploaded stats');
    } finally {
      setSaving(false);
    }
  };

  const openMatchDetail = async (eventId) => {
    setDetailLoading(true);
    setDetail(null);
    try {
      setDetail(await getMatchStats(activeClubId, activeTeamId, eventId));
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to load match detail');
    } finally {
      setDetailLoading(false);
    }
  };

  if (!activeTeamId) {
    return (
      <PageTransition className="flex-1">
        <TopBar title="Stats" />
        <div className="px-4 py-8">
          <EmptyState icon={BarChart3} title="No team selected" subtitle="Select a team to view statistics" />
        </div>
      </PageTransition>
    );
  }

  return (
    <PageTransition className="flex-1">
      <TopBar title="Stats" />
      <div className="px-4 md:px-6 lg:px-8 pb-24 lg:pb-8 max-w-7xl mx-auto w-full">
        <div className="flex items-center justify-between gap-3 mb-3">
          <p className={`text-sm ${isDark ? 'text-white/50' : 'text-gray-500'}`}>{selectedTeam?.teamName || 'Selected team'}</p>
          <div className="flex gap-2 overflow-x-auto">
            {visibleTabs.map((tab) => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`px-3 py-2 rounded-pill text-sm font-semibold transition-colors ${activeTab === tab ? 'bg-primary text-white' : isDark ? 'bg-surface-dark text-white/70' : 'bg-white text-gray-600 shadow-sm'}`}
              >
                {tab}
              </button>
            ))}
          </div>
        </div>

        {loading && <div className="flex justify-center py-10"><LoadingSpinner /></div>}
        {!loading && error && <div className="mb-3 p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{error}</div>}
        {!loading && success && <div className="mb-3 p-3 rounded-card bg-green-500/10 border border-green-500/30 text-green-500 text-sm">{success}</div>}

        {!loading && activeTab === 'Dashboard' && (
          <Dashboard
            isDark={isDark}
            teamStats={teamStats}
            playerAggregate={playerAggregate}
            playerHistory={playerHistory}
            canBrowsePlayers={canBrowsePlayers}
          />
        )}

        {!loading && activeTab === 'Entry' && canEnterStats && (
          <ManualEntry
            isDark={isDark}
            eventOptions={eventOptions}
            eventValues={eventValues}
            teamForm={teamForm}
            setTeamForm={setTeamForm}
            playerRows={playerRows}
            updatePlayerRow={updatePlayerRow}
            saving={saving}
            onSave={handleSaveManual}
          />
        )}

        {!loading && activeTab === 'Upload' && canEnterStats && (
          <UploadPanel
            isDark={isDark}
            eventOptions={eventOptions}
            eventValues={eventValues}
            eventId={teamForm.eventId}
            setEventId={(eventId) => setTeamForm((form) => ({ ...form, eventId }))}
            uploading={uploading}
            saving={saving}
            preview={preview}
            previewFile={previewFile}
            onPreview={handlePreviewUpload}
            onConfirm={handleConfirmPreview}
          />
        )}

        {!loading && activeTab === 'History' && (
          <HistoryPanel isDark={isDark} history={history} onOpen={openMatchDetail} />
        )}
      </div>

      <Modal isOpen={!!detail || detailLoading} onClose={() => setDetail(null)} title={detail?.eventTitle || 'Stats detail'}>
        {detailLoading && <div className="flex justify-center py-8"><LoadingSpinner /></div>}
        {!detailLoading && detail && <MatchDetail isDark={isDark} detail={detail} />}
      </Modal>
    </PageTransition>
  );
}

function Dashboard({ isDark, teamStats, playerAggregate, playerHistory, canBrowsePlayers }) {
  if (!teamStats) return <EmptyState icon={BarChart3} title="No stats yet" subtitle="Stats will appear once an analyst records them" />;
  return (
    <div className="space-y-5">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <StatCard label="Events" value={teamStats.totalEvents || 0} icon={ClipboardList} isDark={isDark} />
        <StatCard label="Goals" value={teamStats.totalGoals || 0} icon={Target} isDark={isDark} />
        <StatCard label="Assists" value={teamStats.totalAssists || 0} icon={Users} isDark={isDark} />
        <StatCard label="Record" value={`${teamStats.wins || 0}-${teamStats.draws || 0}-${teamStats.losses || 0}`} icon={Trophy} isDark={isDark} />
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <StatCard label="Shots" value={`${teamStats.shotsOnTarget || 0}/${teamStats.totalShots || 0}`} icon={Target} isDark={isDark} />
        <StatCard label="Pass %" value={teamStats.averagePassAccuracy != null ? `${Number(teamStats.averagePassAccuracy).toFixed(1)}%` : '-'} icon={BarChart3} isDark={isDark} />
        <StatCard label="Tackles" value={teamStats.tackles || 0} icon={BarChart3} isDark={isDark} />
        <StatCard label="Cards" value={`${teamStats.yellowCards || 0}Y ${teamStats.redCards || 0}R`} icon={BarChart3} isDark={isDark} />
      </div>

      {playerAggregate && (
        <div className={`p-4 rounded-card shadow-sm ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
          <h3 className={`font-semibold mb-3 flex items-center gap-2 ${isDark ? 'text-white' : 'text-black'}`}><User size={18} className="text-primary" />My Stats</h3>
          <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
            <MiniMetric label="Events" value={playerAggregate.eventsPlayed || 0} isDark={isDark} />
            <MiniMetric label="Minutes" value={playerAggregate.minutesPlayed || 0} isDark={isDark} />
            <MiniMetric label="Goals" value={playerAggregate.goals || 0} isDark={isDark} />
            <MiniMetric label="Assists" value={playerAggregate.assists || 0} isDark={isDark} />
            <MiniMetric label="Rating" value={playerAggregate.averageRating != null ? Number(playerAggregate.averageRating).toFixed(1) : '-'} isDark={isDark} />
          </div>
        </div>
      )}

      {canBrowsePlayers && teamStats.playerLeaderboard?.length > 0 && (
        <Leaderboard isDark={isDark} rows={teamStats.playerLeaderboard} />
      )}

      {!canBrowsePlayers && playerHistory?.length > 0 && (
        <PlayerHistory isDark={isDark} rows={playerHistory} />
      )}
    </div>
  );
}

function ManualEntry({ isDark, eventOptions, eventValues, teamForm, setTeamForm, playerRows, updatePlayerRow, saving, onSave }) {
  if (eventOptions.length === 0) return <EmptyState icon={ClipboardList} title="No events found" subtitle="Create a match or training event before recording stats" />;
  return (
    <div className="space-y-4">
      <div className={`p-4 rounded-card shadow-sm ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
        <h3 className={`font-semibold mb-3 ${isDark ? 'text-white' : 'text-black'}`}>Team stats</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <SelectField label="Event *" value={teamForm.eventId} onChange={(eventId) => setTeamForm({ ...teamForm, eventId })} options={eventOptions} optionValues={eventValues} id="select-stats-event" />
          <FormInput label="Opponent" value={teamForm.opponentName} onChange={(e) => setTeamForm({ ...teamForm, opponentName: e.target.value })} />
          <SelectField label="Result" value={teamForm.result} onChange={(result) => setTeamForm({ ...teamForm, result })} options={RESULT_LABELS} optionValues={RESULT_VALUES} />
          <FormInput label="Team Score" type="number" value={teamForm.teamScore} onChange={(e) => setTeamForm({ ...teamForm, teamScore: e.target.value, totalGoals: e.target.value })} />
          <FormInput label="Opponent Score" type="number" value={teamForm.opponentScore} onChange={(e) => setTeamForm({ ...teamForm, opponentScore: e.target.value })} />
          <FormInput label="Venue" value={teamForm.venue} onChange={(e) => setTeamForm({ ...teamForm, venue: e.target.value })} />
          <FormInput label="Competition" value={teamForm.competitionName} onChange={(e) => setTeamForm({ ...teamForm, competitionName: e.target.value })} />
          <FormInput label="Possession %" type="number" value={teamForm.possessionPercent} onChange={(e) => setTeamForm({ ...teamForm, possessionPercent: e.target.value })} />
          <FormInput label="Pass Accuracy %" type="number" value={teamForm.passAccuracy} onChange={(e) => setTeamForm({ ...teamForm, passAccuracy: e.target.value })} />
          <FormInput label="Assists" type="number" value={teamForm.totalAssists} onChange={(e) => setTeamForm({ ...teamForm, totalAssists: e.target.value })} />
          <FormInput label="Shots On Target" type="number" value={teamForm.shotsOnTarget} onChange={(e) => setTeamForm({ ...teamForm, shotsOnTarget: e.target.value })} />
          <FormInput label="Total Shots" type="number" value={teamForm.totalShots} onChange={(e) => setTeamForm({ ...teamForm, totalShots: e.target.value })} />
          <FormInput label="Passes Completed" type="number" value={teamForm.passesCompleted} onChange={(e) => setTeamForm({ ...teamForm, passesCompleted: e.target.value })} />
          <FormInput label="Passes Attempted" type="number" value={teamForm.passesAttempted} onChange={(e) => setTeamForm({ ...teamForm, passesAttempted: e.target.value })} />
          <FormInput label="Tackles" type="number" value={teamForm.tackles} onChange={(e) => setTeamForm({ ...teamForm, tackles: e.target.value })} />
          <FormInput label="Interceptions" type="number" value={teamForm.interceptions} onChange={(e) => setTeamForm({ ...teamForm, interceptions: e.target.value })} />
          <FormInput label="Yellow Cards" type="number" value={teamForm.yellowCards} onChange={(e) => setTeamForm({ ...teamForm, yellowCards: e.target.value })} />
          <FormInput label="Red Cards" type="number" value={teamForm.redCards} onChange={(e) => setTeamForm({ ...teamForm, redCards: e.target.value })} />
        </div>
      </div>

      <div className={`rounded-card shadow-sm overflow-hidden ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
        <div className="p-4 flex items-center justify-between border-b border-black/5">
          <h3 className={`font-semibold ${isDark ? 'text-white' : 'text-black'}`}>Player stats</h3>
          <button onClick={onSave} disabled={saving} className="flex items-center gap-2 px-4 py-2 rounded-card bg-primary text-white text-sm font-semibold disabled:opacity-60">
            <Save size={16} />{saving ? 'Saving...' : 'Save Stats'}
          </button>
        </div>
        <PlayerEntryTable isDark={isDark} rows={playerRows} updatePlayerRow={updatePlayerRow} />
      </div>
    </div>
  );
}

function PlayerEntryTable({ isDark, rows, updatePlayerRow }) {
  const fields = [
    ['minutesPlayed', 'Min'], ['goals', 'G'], ['assists', 'A'], ['shotsOnTarget', 'SOT'], ['totalShots', 'Shots'],
    ['passesCompleted', 'Pass'], ['passesAttempted', 'Att'], ['passAccuracy', 'Pass %'], ['tackles', 'Tkl'],
    ['interceptions', 'Int'], ['yellowCards', 'Y'], ['redCards', 'R'], ['rating', 'Rate'],
  ];
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead className={isDark ? 'text-white/50' : 'text-gray-500'}>
          <tr className={isDark ? 'border-b border-white/10' : 'border-b border-gray-100'}>
            <th className="text-left p-3 font-medium min-w-[180px]">Player</th>
            {fields.map(([, label]) => <th key={label} className="text-left p-3 font-medium min-w-[74px]">{label}</th>)}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, index) => (
            <tr key={row.playerUserId} className={isDark ? 'border-b border-white/5' : 'border-b border-gray-50'}>
              <td className={`p-3 font-semibold ${isDark ? 'text-white' : 'text-black'}`}>{row.playerName}</td>
              {fields.map(([key]) => (
                <td key={key} className="p-2">
                  <input
                    type="number"
                    value={row[key]}
                    onChange={(e) => updatePlayerRow(index, key, e.target.value)}
                    className={`w-16 px-2 py-2 rounded-card border text-sm outline-none ${isDark ? 'bg-surface-darkest text-white border-white/10' : 'bg-white text-black border-gray-200'}`}
                  />
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function UploadPanel({ isDark, eventOptions, eventValues, eventId, setEventId, uploading, saving, preview, previewFile, onPreview, onConfirm }) {
  return (
    <div className="space-y-4">
      <div className={`p-4 rounded-card shadow-sm ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
        <SelectField label="Event *" value={eventId} onChange={setEventId} options={eventOptions} optionValues={eventValues} id="select-upload-event" />
        <label className={`mt-4 flex flex-col items-center justify-center gap-2 p-8 rounded-card border-2 border-dashed cursor-pointer ${isDark ? 'border-white/10 text-white/60 hover:bg-white/5' : 'border-gray-200 text-gray-500 hover:bg-gray-50'}`}>
          <Upload size={28} className="text-primary" />
          <span className="text-sm font-semibold">{uploading ? 'Parsing...' : 'Drop or choose CSV/PDF'}</span>
          <input type="file" accept=".csv,.pdf" className="hidden" onChange={(e) => e.target.files?.[0] && onPreview(e.target.files[0])} />
        </label>
        <p className={`mt-3 text-xs ${isDark ? 'text-white/40' : 'text-gray-500'}`}>
          CSV rows should include row_type values TEAM and PLAYER. Players can be matched by player_user_id, player_email, or player_name.
        </p>
      </div>

      {preview && (
        <div className={`p-4 rounded-card shadow-sm ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
          <div className="flex items-center justify-between gap-3">
            <div>
              <h3 className={`font-semibold ${isDark ? 'text-white' : 'text-black'}`}>Preview</h3>
              <p className={`text-sm ${isDark ? 'text-white/50' : 'text-gray-500'}`}>{previewFile?.name || preview.fileName} - {preview.message}</p>
            </div>
            <button onClick={onConfirm} disabled={!preview.canSave || saving} className="px-4 py-2 rounded-card bg-primary text-white text-sm font-semibold disabled:opacity-60">
              {saving ? 'Saving...' : 'Confirm Save'}
            </button>
          </div>
          {preview.parsedStats && <PreviewStats isDark={isDark} stats={preview.parsedStats} />}
        </div>
      )}
    </div>
  );
}

function PreviewStats({ isDark, stats }) {
  return (
    <div className="mt-4">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <MiniMetric label="Opponent" value={stats.opponentName || '-'} isDark={isDark} />
        <MiniMetric label="Score" value={`${stats.teamScore ?? '-'}-${stats.opponentScore ?? '-'}`} isDark={isDark} />
        <MiniMetric label="Result" value={stats.result || '-'} isDark={isDark} />
        <MiniMetric label="Players" value={stats.playerStats?.length || 0} isDark={isDark} />
      </div>
    </div>
  );
}

function HistoryPanel({ isDark, history, onOpen }) {
  if (history.length === 0) return <EmptyState icon={ClipboardList} title="No history yet" subtitle="Saved match and training stats will appear here" />;
  return (
    <div className="space-y-2">
      {history.map((item) => (
        <button key={item.matchStatsId} onClick={() => onOpen(item.eventId)} className={`w-full p-4 rounded-card shadow-sm text-left transition-colors ${isDark ? 'bg-surface-dark hover:bg-white/5' : 'bg-white hover:bg-gray-50'}`}>
          <div className="flex items-center justify-between gap-3">
            <div>
              <h3 className={`font-semibold ${isDark ? 'text-white' : 'text-black'}`}>{item.eventTitle}</h3>
              <p className={`text-sm mt-1 ${isDark ? 'text-white/50' : 'text-gray-500'}`}>
                {item.eventType} - {new Date(item.eventStartAt).toLocaleDateString()} {item.opponentName ? `- vs ${item.opponentName}` : ''}
              </p>
            </div>
            <div className="flex items-center gap-3">
              <span className={`text-sm font-bold ${isDark ? 'text-white' : 'text-black'}`}>{item.teamScore ?? '-'}-{item.opponentScore ?? '-'}</span>
              <Eye size={18} className="text-primary" />
            </div>
          </div>
        </button>
      ))}
    </div>
  );
}

function MatchDetail({ isDark, detail }) {
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <MiniMetric label="Score" value={`${detail.teamScore ?? '-'}-${detail.opponentScore ?? '-'}`} isDark={isDark} />
        <MiniMetric label="Result" value={detail.result || '-'} isDark={isDark} />
        <MiniMetric label="Shots" value={`${detail.shotsOnTarget ?? 0}/${detail.totalShots ?? 0}`} isDark={isDark} />
        <MiniMetric label="Pass %" value={detail.passAccuracy != null ? `${Number(detail.passAccuracy).toFixed(1)}%` : '-'} isDark={isDark} />
      </div>
      <ReadonlyPlayerTable isDark={isDark} rows={detail.playerStats || []} />
    </div>
  );
}

function Leaderboard({ isDark, rows }) {
  return (
    <div className={`rounded-card shadow-sm overflow-hidden ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
      <div className="p-4 border-b border-black/5">
        <h3 className={`font-semibold ${isDark ? 'text-white' : 'text-black'}`}>Player leaderboard</h3>
      </div>
      <ReadonlyPlayerAggregateTable isDark={isDark} rows={rows} />
    </div>
  );
}

function PlayerHistory({ isDark, rows }) {
  return (
    <div className={`rounded-card shadow-sm overflow-hidden ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
      <div className="p-4 border-b border-black/5">
        <h3 className={`font-semibold ${isDark ? 'text-white' : 'text-black'}`}>My match history</h3>
      </div>
      <ReadonlyPlayerTable isDark={isDark} rows={rows} />
    </div>
  );
}

function ReadonlyPlayerAggregateTable({ isDark, rows }) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead className={isDark ? 'text-white/50' : 'text-gray-500'}>
          <tr className={isDark ? 'border-b border-white/10' : 'border-b border-gray-100'}>
            {['Player', 'Events', 'Min', 'G', 'A', 'Shots', 'Pass %', 'Rating'].map((h) => <th key={h} className="text-left p-3 font-medium">{h}</th>)}
          </tr>
        </thead>
        <tbody>
          {rows.map((p) => (
            <tr key={p.playerUserId} className={isDark ? 'border-b border-white/5' : 'border-b border-gray-50'}>
              <td className={`p-3 font-semibold ${isDark ? 'text-white' : 'text-black'}`}>{p.playerName}</td>
              <td className="p-3">{p.eventsPlayed}</td>
              <td className="p-3">{p.minutesPlayed}</td>
              <td className="p-3">{p.goals}</td>
              <td className="p-3">{p.assists}</td>
              <td className="p-3">{p.shotsOnTarget}/{p.totalShots}</td>
              <td className="p-3">{p.averagePassAccuracy != null ? Number(p.averagePassAccuracy).toFixed(1) : '-'}</td>
              <td className="p-3">{p.averageRating != null ? Number(p.averageRating).toFixed(1) : '-'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function ReadonlyPlayerTable({ isDark, rows }) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead className={isDark ? 'text-white/50' : 'text-gray-500'}>
          <tr className={isDark ? 'border-b border-white/10' : 'border-b border-gray-100'}>
            {['Player', 'Min', 'G', 'A', 'SOT', 'Shots', 'Pass %', 'Tkl', 'Int', 'Cards', 'Rating'].map((h) => <th key={h} className="text-left p-3 font-medium">{h}</th>)}
          </tr>
        </thead>
        <tbody>
          {rows.map((p) => (
            <tr key={p.playerMatchStatsId} className={isDark ? 'border-b border-white/5' : 'border-b border-gray-50'}>
              <td className={`p-3 font-semibold min-w-[160px] ${isDark ? 'text-white' : 'text-black'}`}>{p.playerName}</td>
              <td className="p-3">{p.minutesPlayed ?? '-'}</td>
              <td className="p-3">{p.goals ?? 0}</td>
              <td className="p-3">{p.assists ?? 0}</td>
              <td className="p-3">{p.shotsOnTarget ?? 0}</td>
              <td className="p-3">{p.totalShots ?? 0}</td>
              <td className="p-3">{p.passAccuracy != null ? Number(p.passAccuracy).toFixed(1) : '-'}</td>
              <td className="p-3">{p.tackles ?? 0}</td>
              <td className="p-3">{p.interceptions ?? 0}</td>
              <td className="p-3">{p.yellowCards ?? 0}Y {p.redCards ?? 0}R</td>
              <td className="p-3">{p.rating != null ? Number(p.rating).toFixed(1) : '-'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function StatCard({ label, value, icon: Icon, isDark }) {
  return (
    <div className={`p-4 rounded-card shadow-sm ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
      <div className="flex items-center gap-2">
        <Icon size={18} className="text-primary" />
        <p className={`text-xs ${isDark ? 'text-white/40' : 'text-gray-500'}`}>{label}</p>
      </div>
      <p className={`text-2xl font-bold mt-2 ${isDark ? 'text-white' : 'text-black'}`}>{value}</p>
    </div>
  );
}

function MiniMetric({ label, value, isDark }) {
  return (
    <div className={`p-3 rounded-card ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
      <p className={`text-xs ${isDark ? 'text-white/40' : 'text-gray-500'}`}>{label}</p>
      <p className={`text-sm font-bold mt-1 ${isDark ? 'text-white' : 'text-black'}`}>{value}</p>
    </div>
  );
}
