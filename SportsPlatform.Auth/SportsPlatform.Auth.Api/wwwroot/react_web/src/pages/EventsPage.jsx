import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Calendar, Trophy, Dumbbell, FileText, FlaskConical, ChevronDown, ChevronUp, CheckCircle, XCircle, Clock, Plus, ClipboardCheck } from 'lucide-react';
import TopBar from '../components/TopBar';
import PageTransition from '../components/PageTransition';
import EmptyState from '../components/EmptyState';
import LoadingSpinner from '../components/LoadingSpinner';
import Modal from '../components/Modal';
import SelectField from '../components/SelectField';
import useTheme from '../hooks/useTheme';
import useAuth from '../hooks/useAuth';
import useClub from '../hooks/useClub';
import { getTeamEvents } from '../services/eventService';
import { getEventAttendance, getMyAttendance, recordAttendance } from '../services/attendanceService';
import { getTeamMembers } from '../services/teamService';

const EVENT_COLORS = {
  Match: 'bg-blue-500',
  Training: 'bg-green-700',
  Meeting: 'bg-green-400',
  Test: 'bg-[#082E6F]',
};

const EVENT_ICONS = {
  Match: Trophy,
  Training: Dumbbell,
  Meeting: FileText,
  Test: FlaskConical,
};

const STATUS_ICONS = {
  Present: { icon: CheckCircle, color: 'text-green-500' },
  Absent: { icon: XCircle, color: 'text-red-500' },
  Late: { icon: Clock, color: 'text-yellow-500' },
  Excused: { icon: CheckCircle, color: 'text-blue-400' },
};

const ATTENDANCE_STATUSES = ['Present', 'Absent', 'Late', 'Excused'];

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export default function EventsPage() {
  const { isDark } = useTheme();
  const navigate = useNavigate();
  const { currentUser, isAdmin } = useAuth();
  const { activeClubId, activeTeamId } = useClub();
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [filter, setFilter] = useState('All');
  const [expandedEvent, setExpandedEvent] = useState(null);
  const [attendance, setAttendance] = useState([]);
  const [attendanceLoading, setAttendanceLoading] = useState(false);

  // Attendance recording modal
  const [showAttendanceForm, setShowAttendanceForm] = useState(false);
  const [attendanceEventId, setAttendanceEventId] = useState(null);
  const [attendanceEventDate, setAttendanceEventDate] = useState('');
  const [players, setPlayers] = useState([]);
  const [attendanceEntries, setAttendanceEntries] = useState([]);
  const [savingAttendance, setSavingAttendance] = useState(false);
  const [attendanceError, setAttendanceError] = useState('');

  // Derive manager role
  const roles = new Set(currentUser?.roles || []);
  const canManageAttendance = roles.has('ClubManager') || roles.has('TeamManager') || isAdmin;
  const canViewAttendance = canManageAttendance || roles.has('Player');

  useEffect(() => {
    if (!activeClubId || !activeTeamId) {
      setEvents([]);
      return;
    }
    let cancelled = false;
    const fetch = async () => {
      setLoading(true);
      setError('');
      try {
        const data = await getTeamEvents(activeClubId, activeTeamId);
        if (!cancelled) setEvents(data || []);
      } catch (err) {
        if (!cancelled) setError(err.response?.data?.error || 'Failed to load events');
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    fetch();
    return () => { cancelled = true; };
  }, [activeClubId, activeTeamId]);

  const handleToggleAttendance = async (eventId) => {
    if (expandedEvent === eventId) {
      setExpandedEvent(null);
      setAttendance([]);
      return;
    }
    setExpandedEvent(eventId);
    setAttendanceLoading(true);
    try {
      if (canManageAttendance) {
        const data = await getEventAttendance(activeClubId, activeTeamId, eventId);
        setAttendance(data || []);
      } else {
        const mine = await getMyAttendance(activeClubId, activeTeamId, eventId);
        setAttendance(mine ? [mine] : []);
      }
    } catch {
      setAttendance([]);
    } finally {
      setAttendanceLoading(false);
    }
  };

  const buildAttendanceEntries = (teamPlayers, existingAttendance = []) => {
    const existingByPlayer = new Map((existingAttendance || []).map((item) => [item.playerUserId, item]));
    return teamPlayers.map((p) => {
      const existing = existingByPlayer.get(p.userId);
      return {
        playerUserId: p.userId,
        playerName: p.name,
        status: existing?.status || 'Present',
        notes: existing?.notes || '',
      };
    });
  };

  const loadAttendanceForFormDate = async (dateValue, teamPlayers = players) => {
    if (!activeClubId || !activeTeamId || !attendanceEventId || !dateValue) return;
    try {
      const existing = await getEventAttendance(activeClubId, activeTeamId, attendanceEventId, dateValue);
      setAttendanceEntries(buildAttendanceEntries(teamPlayers, existing || []));
    } catch {
      setAttendanceEntries(buildAttendanceEntries(teamPlayers));
    }
  };

  // Open the attendance recording modal
  const openAttendanceForm = async (event) => {
    setAttendanceEventId(event.eventId);
    const eventDate = new Date(event.startAt);
    const dateStr = `${eventDate.getFullYear()}-${String(eventDate.getMonth() + 1).padStart(2, '0')}-${String(eventDate.getDate()).padStart(2, '0')}`;
    setAttendanceEventDate(dateStr);
    setAttendanceError('');
    setShowAttendanceForm(true);

    // Load players and any existing marks for this date
    try {
      const [members, existing] = await Promise.all([
        getTeamMembers(activeClubId, activeTeamId),
        getEventAttendance(activeClubId, activeTeamId, event.eventId, dateStr).catch(() => []),
      ]);
      const teamPlayers = (members || []).filter((m) => m.role === 'Player');
      setPlayers(teamPlayers);
      setAttendanceEntries(buildAttendanceEntries(teamPlayers, existing || []));
    } catch {
      setPlayers([]);
      setAttendanceEntries([]);
    }
  };

  const handleSaveAttendance = async () => {
    if (attendanceEntries.length === 0) { setAttendanceError('No players found to record attendance for'); return; }
    setAttendanceError('');
    setSavingAttendance(true);
    try {
      await recordAttendance(activeClubId, activeTeamId, attendanceEventId, {
        instanceDate: attendanceEventDate,
        records: attendanceEntries.map((e) => ({
          playerUserId: e.playerUserId,
          status: e.status,
          notes: e.notes || null,
        })),
      });
      setShowAttendanceForm(false);
      // Refresh the expanded attendance view
      if (expandedEvent === attendanceEventId) {
        const data = await getEventAttendance(activeClubId, activeTeamId, attendanceEventId);
        setAttendance(data || []);
      }
    } catch (err) {
      setAttendanceError(err.response?.data?.error || 'Failed to save attendance');
    } finally {
      setSavingAttendance(false);
    }
  };

  const updateEntryStatus = (idx, status) => {
    setAttendanceEntries((prev) => prev.map((e, i) => i === idx ? { ...e, status } : e));
  };

  const updateEntryNotes = (idx, notes) => {
    setAttendanceEntries((prev) => prev.map((e, i) => i === idx ? { ...e, notes } : e));
  };

  const handleAttendanceDateChange = async (dateValue) => {
    setAttendanceEventDate(dateValue);
    await loadAttendanceForFormDate(dateValue);
  };

  const filtered = filter === 'All' ? events : events.filter((e) => e.eventType === filter);
  const types = ['All', 'Match', 'Training', 'Meeting', 'Test'];

  if (!activeTeamId) {
    return (
      <PageTransition className="flex-1">
        <TopBar title="Events" />
        <div className="px-4 py-8">
          <EmptyState icon={Calendar} title="No team selected" subtitle="Select a team to see events" />
        </div>
      </PageTransition>
    );
  }

  return (
    <PageTransition className="flex-1">
      <TopBar title="Events" />

      <div className="px-4 md:px-6 lg:px-8 pb-24 lg:pb-8 max-w-7xl mx-auto w-full">
        {/* Filter chips */}
        <div className="flex gap-2 overflow-x-auto pb-3 -mx-4 px-4 lg:mx-0 lg:px-0">
          {types.map((type) => (
            <button
              key={type}
              onClick={() => setFilter(type)}
              className={`px-4 py-2 rounded-pill text-sm font-medium whitespace-nowrap transition-all duration-200 ${
                filter === type
                  ? 'bg-primary text-white shadow-md'
                  : isDark
                    ? 'bg-surface-dark text-white/70 hover:bg-white/10'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              {type}
            </button>
          ))}
        </div>

        {/* Loading */}
        {loading && (
          <div className="flex justify-center py-8"><LoadingSpinner /></div>
        )}

        {/* Error */}
        {error && (
          <div className="p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm font-medium mt-2">
            {error}
          </div>
        )}

        {/* Event list */}
        {!loading && !error && filtered.length === 0 && (
          <EmptyState icon={Calendar} title="No events yet" subtitle="Events will appear here once added" />
        )}
        {!loading && !error && filtered.length > 0 && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3 md:gap-4 mt-2">
            {filtered.map((event) => {
              const Icon = EVENT_ICONS[event.eventType] || Calendar;
              const date = new Date(event.startAt);
              const dateStr = `${date.getDate()} ${MONTHS[date.getMonth()]} ${date.getFullYear()}`;
              const timeStr = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
              const isExpanded = expandedEvent === event.eventId;

              return (
                <div key={event.eventId} className={`rounded-card shadow-sm overflow-hidden ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
                  <div className="flex items-center gap-4 p-4">
                    <div className={`w-12 h-12 rounded-card flex items-center justify-center ${EVENT_COLORS[event.eventType] || 'bg-gray-500'}`}>
                      <Icon size={22} className="text-white" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className={`text-sm font-bold ${isDark ? 'text-white' : 'text-black'}`}>
                          {event.title || event.eventType}
                        </span>
                        <span className={`text-badge px-2 py-0.5 rounded-pill ${
                          isDark ? 'bg-white/10 text-white/60' : 'bg-gray-100 text-gray-500'
                        }`}>
                          {timeStr}
                        </span>
                      </div>
                      <p className={`text-body-sm truncate ${isDark ? 'text-white/60' : 'text-gray-500'}`}>
                        {dateStr} • {event.description || event.eventType}
                      </p>
                      {event.location && (
                        <p className={`text-badge truncate ${isDark ? 'text-white/40' : 'text-gray-400'}`}>
                          📍 {event.location}
                        </p>
                      )}
                    </div>
                    <div className="flex items-center gap-1">
                      {canManageAttendance && (
                        <button
                          onClick={() => openAttendanceForm(event)}
                          className={`p-1.5 rounded-full transition-colors ${isDark ? 'hover:bg-white/10' : 'hover:bg-gray-100'}`}
                          title="Record attendance"
                        >
                          <ClipboardCheck size={18} className="text-primary" />
                        </button>
                      )}
                      {canViewAttendance && (
                        <button
                          onClick={() => handleToggleAttendance(event.eventId)}
                          className={`p-1.5 rounded-full transition-colors ${isDark ? 'hover:bg-white/10' : 'hover:bg-gray-100'}`}
                          title="View attendance"
                        >
                          {isExpanded
                            ? <ChevronUp size={18} className={isDark ? 'text-white/50' : 'text-gray-400'} />
                            : <ChevronDown size={18} className={isDark ? 'text-white/50' : 'text-gray-400'} />}
                        </button>
                      )}
                    </div>
                  </div>

                  {/* Attendance panel */}
                  {isExpanded && (
                    <div className={`px-4 pb-3 border-t ${isDark ? 'border-white/5' : 'border-gray-100'}`}>
                      {attendanceLoading && <div className="flex justify-center py-3"><LoadingSpinner /></div>}
                      {!attendanceLoading && attendance.length === 0 && (
                        <p className={`text-xs py-3 text-center ${isDark ? 'text-white/40' : 'text-gray-400'}`}>No attendance recorded yet</p>
                      )}
                      {!attendanceLoading && attendance.length > 0 && (
                        <div className="space-y-1 mt-2">
                          {canManageAttendance && (
                            <div className="flex gap-1.5 flex-wrap pb-1">
                              {ATTENDANCE_STATUSES.map((status) => {
                                const count = attendance.filter((item) => item.status === status).length;
                                return (
                                  <span key={status} className={`text-[10px] px-2 py-0.5 rounded-pill ${isDark ? 'bg-white/10 text-white/50' : 'bg-gray-100 text-gray-500'}`}>
                                    {status}: {count}
                                  </span>
                                );
                              })}
                            </div>
                          )}
                          {attendance.map((a) => {
                            const statusInfo = STATUS_ICONS[a.status] || STATUS_ICONS.Present;
                            const StatusIcon = statusInfo.icon;
                            return (
                              <div key={a.attendanceId} className="flex items-start gap-2 py-1">
                                <StatusIcon size={14} className={statusInfo.color} />
                                <div className="flex-1 min-w-0">
                                  {canManageAttendance ? (
                                    <button onClick={() => navigate(`/app/members/${a.playerUserId}?tab=attendance`)}
                                      className={`text-xs font-semibold text-left hover:text-primary ${isDark ? 'text-white/70' : 'text-gray-600'}`}>
                                      {a.playerName}
                                    </button>
                                  ) : (
                                    <span className={`text-xs ${isDark ? 'text-white/70' : 'text-gray-600'}`}>{a.playerName}</span>
                                  )}
                                  {a.notes && <p className={`text-[10px] mt-0.5 ${isDark ? 'text-white/35' : 'text-gray-400'}`}>{a.notes}</p>}
                                </div>
                                <span className={`text-[10px] ${isDark ? 'text-white/40' : 'text-gray-400'}`}>{a.status}</span>
                              </div>
                            );
                          })}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* ===== Attendance Recording Modal ===== */}
      <Modal isOpen={showAttendanceForm} onClose={() => setShowAttendanceForm(false)} title="Record Attendance">
        <div className="flex flex-col gap-3">
          {attendanceError && <div className="p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{attendanceError}</div>}
          <div>
            <label className={`block text-xs font-medium mb-1 ${isDark ? 'text-white/50' : 'text-gray-500'}`}>Attendance date</label>
            <input
              type="date"
              value={attendanceEventDate}
              onChange={(event) => handleAttendanceDateChange(event.target.value)}
              className={`w-full px-4 py-3 rounded-card border-2 text-body outline-none transition-colors ${isDark ? 'bg-surface-dark text-white border-accent/50 focus:border-accent' : 'bg-white text-black border-accent/50 focus:border-accent'}`}
              id="input-attendance-date"
            />
            <p className={`text-xs mt-1 ${isDark ? 'text-white/40' : 'text-gray-400'}`}>{players.length} players</p>
          </div>
          {attendanceEntries.length === 0 && (
            <p className={`text-sm text-center py-4 ${isDark ? 'text-white/40' : 'text-gray-400'}`}>No players found on this team</p>
          )}
          <div className="max-h-[50vh] overflow-y-auto space-y-2">
            {attendanceEntries.map((entry, idx) => {
              const statusInfo = STATUS_ICONS[entry.status] || STATUS_ICONS.Present;
              const StatusIcon = statusInfo.icon;
              return (
                <div key={entry.playerUserId} className={`p-3 rounded-card ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-2">
                      <StatusIcon size={14} className={statusInfo.color} />
                      <span className={`text-sm font-medium ${isDark ? 'text-white' : 'text-black'}`}>{entry.playerName}</span>
                    </div>
                  </div>
                  <div className="flex gap-1.5 flex-wrap">
                    {ATTENDANCE_STATUSES.map((s) => (
                      <button key={s} onClick={() => updateEntryStatus(idx, s)}
                        className={`px-3 py-1 rounded-pill text-xs font-medium transition-all ${
                          entry.status === s
                            ? s === 'Present' ? 'bg-green-500 text-white'
                              : s === 'Absent' ? 'bg-red-500 text-white'
                                : s === 'Late' ? 'bg-yellow-500 text-white'
                                  : 'bg-blue-500 text-white'
                            : isDark ? 'bg-white/10 text-white/60' : 'bg-gray-200 text-gray-600'
                        }`}>
                        {s}
                      </button>
                    ))}
                  </div>
                  <input
                    value={entry.notes}
                    onChange={(event) => updateEntryNotes(idx, event.target.value)}
                    placeholder="Notes"
                    className={`w-full mt-2 px-3 py-2 rounded-card border text-xs outline-none transition-colors ${isDark ? 'bg-surface-dark border-white/10 text-white placeholder:text-white/30' : 'bg-white border-gray-200 text-black placeholder:text-gray-400'}`}
                  />
                </div>
              );
            })}
          </div>
          <button onClick={handleSaveAttendance} disabled={savingAttendance || attendanceEntries.length === 0}
            className="w-full py-3 rounded-card bg-primary text-white font-semibold hover:bg-primary-dark transition-colors disabled:opacity-60"
            id="btn-save-attendance">
            {savingAttendance ? 'Saving...' : 'Save Attendance'}
          </button>
        </div>
      </Modal>
    </PageTransition>
  );
}
