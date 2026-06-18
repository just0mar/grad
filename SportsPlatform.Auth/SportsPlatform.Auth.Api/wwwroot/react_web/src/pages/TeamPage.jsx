import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import TopBar from '../components/TopBar';
import PageTransition from '../components/PageTransition';
import Avatar from '../components/Avatar';
import EmptyState from '../components/EmptyState';
import LoadingSpinner from '../components/LoadingSpinner';
import FormInput from '../components/FormInput';
import SelectField from '../components/SelectField';
import useTheme from '../hooks/useTheme';
import useClub from '../hooks/useClub';
import useAuth from '../hooks/useAuth';
import { getTeamMembers } from '../services/teamService';
import { createEvent, getCurrentTeamSeason, getTeamEvents } from '../services/eventService';
import { getTeamAnnouncements } from '../services/announcementService';
import { getTeamStats, getMatchHistory, getMatchStats } from '../services/statsService';
import { getTeamPlans, getTeamLineups } from '../services/planService';
import { getPlayerFitnessRecords } from '../services/fitnessService';
import { getPlayerMedicalRecords } from '../services/medicalService';
import { getEventAttendance, getMyAttendance, recordAttendance } from '../services/attendanceService';
import { getRoleAccess, roleLabel } from '../utils/roleAccess';
import { Activity, BarChart3, Calendar, ChevronLeft, ChevronRight, ClipboardCheck, Eye, FileText, HeartPulse, Megaphone, Plus, ShieldCheck, Trophy, Users, X } from 'lucide-react';

const eventDate = (value) => new Date(value).toLocaleDateString([], { month: 'short', day: 'numeric' });
const CALENDAR_MODES = ['Month', 'Week', 'Day'];
const ATTENDANCE_STATUSES = ['Present', 'Absent', 'Late', 'Excused'];

export default function TeamPage() {
  const { isDark } = useTheme();
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const { currentUser, isAdmin } = useAuth();
  const { activeClubId, activeTeamId, selectedTeam } = useClub();
  const access = getRoleAccess(currentUser, isAdmin);

  const [members, setMembers] = useState([]);
  const [events, setEvents] = useState([]);
  const [announcements, setAnnouncements] = useState([]);
  const [teamStats, setTeamStats] = useState(null);
  const [matchHistory, setMatchHistory] = useState([]);
  const [plans, setPlans] = useState([]);
  const [lineups, setLineups] = useState([]);
  const [medicalSummary, setMedicalSummary] = useState([]);
  const [fitnessSummary, setFitnessSummary] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [calendarMode, setCalendarMode] = useState('Month');
  const [calendarDate, setCalendarDate] = useState(new Date());
  const [selectedCalendarEvent, setSelectedCalendarEvent] = useState(null);
  const [eventAttendance, setEventAttendance] = useState([]);
  const [eventStats, setEventStats] = useState(null);
  const [eventDetailLoading, setEventDetailLoading] = useState(false);
  const [showAttendanceForm, setShowAttendanceForm] = useState(false);
  const [attendanceDate, setAttendanceDate] = useState('');
  const [attendanceEntries, setAttendanceEntries] = useState([]);
  const [attendanceError, setAttendanceError] = useState('');
  const [savingAttendance, setSavingAttendance] = useState(false);
  const [showEventForm, setShowEventForm] = useState(false);
  const [eventForm, setEventForm] = useState({ title: '', eventType: 'Training', startAt: '', endAt: '', location: '', description: '' });
  const [eventFormError, setEventFormError] = useState('');
  const [savingEvent, setSavingEvent] = useState(false);
  const [leaderboardSort, setLeaderboardSort] = useState('goals');

  useEffect(() => {
    const action = searchParams.get('action');
    const focus = searchParams.get('focus');
    const eventType = searchParams.get('type');
    if (action === 'create-event' && access.canManageEvents) {
      handleCalendarSlotClick(new Date(), ['Match', 'Training', 'Meeting', 'Test'].includes(eventType) ? eventType : 'Training');
      setSearchParams({}, { replace: true });
    }
    if (action === 'attendance') {
      setCalendarDate(new Date());
      setCalendarMode('Week');
      setSearchParams({}, { replace: true });
    }
    if (focus === 'fitness' || focus === 'medical') {
      setSearchParams({}, { replace: true });
      requestAnimationFrame(() => {
        document.getElementById(`team-section-${focus}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      });
    }
  }, [searchParams, access.canManageEvents]);

  useEffect(() => {
    if (!activeClubId || !activeTeamId) {
      setMembers([]);
      setEvents([]);
      return;
    }

    let cancelled = false;
    const loadHub = async () => {
      setLoading(true);
      setError('');
      try {
        const [memberData, eventData, announcementData, statsData, historyData, planData, lineupData] = await Promise.all([
          getTeamMembers(activeClubId, activeTeamId),
          getTeamEvents(activeClubId, activeTeamId).catch(() => []),
          getTeamAnnouncements(activeClubId, activeTeamId).catch(() => []),
          getTeamStats(activeClubId, activeTeamId).catch(() => null),
          getMatchHistory(activeClubId, activeTeamId).catch(() => []),
          access.canViewPlans ? getTeamPlans(activeClubId, activeTeamId).catch(() => []) : [],
          access.canViewPlans ? getTeamLineups(activeClubId, activeTeamId).catch(() => []) : [],
        ]);

        if (cancelled) return;
        const roster = memberData || [];
        const players = roster.filter((m) => m.role === 'Player');
        setMembers(roster);
        setEvents(eventData || []);
        setAnnouncements(announcementData || []);
        setTeamStats(statsData);
        setMatchHistory(historyData || []);
        setPlans(planData || []);
        setLineups(lineupData || []);

        if (access.isDoctor || access.isManager) {
          const medicalRows = await Promise.all(players.slice(0, 24).map(async (player) => {
            const records = await getPlayerMedicalRecords(activeClubId, activeTeamId, player.userId).catch(() => []);
            const latest = (records || []).sort((a, b) => new Date(b.recordDate) - new Date(a.recordDate))[0];
            return { player, latest, pending: (records || []).flatMap((r) => r.documentRequests || []).filter((r) => r.status === 'Pending').length };
          }));
          if (!cancelled) setMedicalSummary(medicalRows);
        } else {
          setMedicalSummary([]);
        }

        if (access.isFitnessCoach || access.isManager) {
          const fitnessRows = await Promise.all(players.slice(0, 24).map(async (player) => {
            const records = await getPlayerFitnessRecords(activeClubId, activeTeamId, player.userId).catch(() => []);
            const latest = (records || []).sort((a, b) => new Date(b.testDate) - new Date(a.testDate))[0];
            return { player, latest, count: records?.length || 0 };
          }));
          if (!cancelled) setFitnessSummary(fitnessRows);
        } else {
          setFitnessSummary([]);
        }
      } catch (err) {
        if (!cancelled) setError(err.response?.data?.error || 'Failed to load team hub');
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    loadHub();
    return () => { cancelled = true; };
  }, [activeClubId, activeTeamId, access.canViewPlans, access.canViewStats, access.isDoctor, access.isFitnessCoach, access.isManager]);

  const players = members.filter((m) => m.role === 'Player');
  const upcoming = events
    .filter((e) => new Date(e.startAt) >= new Date())
    .sort((a, b) => new Date(a.startAt) - new Date(b.startAt))
    .slice(0, 5);
  const calendarEvents = expandCalendarEvents(events, calendarDate, calendarMode);
  const teamHero = buildTeamHero(teamStats, matchHistory, currentUser?.userId);
  const medicalByUser = new Map(medicalSummary.map((row) => [row.player.userId, row]));
  const fitnessByUser = new Map(fitnessSummary.map((row) => [row.player.userId, row]));
  const sortedLeaderboard = sortLeaderboard(teamStats?.playerLeaderboard || [], leaderboardSort);

  const openMember = (member) => {
    if (access.isPlayer && member.userId !== currentUser?.userId) return;
    navigate(member.userId === currentUser?.userId ? '/app/profile' : `/app/members/${member.userId}`);
  };

  const openCalendarEvent = async (event) => {
    setSelectedCalendarEvent(event);
    setEventAttendance([]);
    setEventStats(null);
    setEventDetailLoading(true);
    try {
      const [attendanceData, statsData] = await Promise.all([
        access.canManageAttendance
          ? getEventAttendance(activeClubId, activeTeamId, event.eventId, toDateInput(event.instanceStartAt || event.startAt)).catch(() => [])
          : access.isPlayer
            ? getMyAttendance(activeClubId, activeTeamId, event.eventId, toDateInput(event.instanceStartAt || event.startAt)).then((row) => row ? [row] : []).catch(() => [])
            : Promise.resolve([]),
        event.eventType === 'Match' ? getMatchStats(activeClubId, activeTeamId, event.eventId).catch(() => null) : Promise.resolve(null),
      ]);
      setEventAttendance(attendanceData || []);
      setEventStats(statsData);
    } finally {
      setEventDetailLoading(false);
    }
  };

  const handleCalendarSlotClick = (date, eventType = 'Training') => {
    if (!access.canManageEvents) return;
    const start = toDateTimeLocal(setTime(date, 18, 0));
    const end = new Date(start);
    end.setHours(end.getHours() + 1);
    setEventForm({ title: '', eventType, startAt: start, endAt: toDateTimeLocal(end), location: '', description: '' });
    setEventFormError('');
    setShowEventForm(true);
  };

  const handleSaveEvent = async () => {
    if (!eventForm.title.trim() || !eventForm.eventType || !eventForm.startAt) {
      setEventFormError('Add a title, type, and start time.');
      return;
    }
    setSavingEvent(true);
    setEventFormError('');
    try {
      const season = await getCurrentTeamSeason(activeClubId, activeTeamId);
      if (!season?.seasonId) throw new Error('No active season found for this team.');
      await createEvent(activeClubId, activeTeamId, {
        seasonId: season.seasonId,
        title: eventForm.title.trim(),
        eventType: eventForm.eventType,
        startAt: new Date(eventForm.startAt).toISOString(),
        endAt: eventForm.endAt ? new Date(eventForm.endAt).toISOString() : undefined,
        location: eventForm.location.trim() || undefined,
        description: eventForm.description.trim() || undefined,
      });
      setShowEventForm(false);
      const refreshed = await getTeamEvents(activeClubId, activeTeamId).catch(() => []);
      setEvents(refreshed || []);
    } catch (err) {
      setEventFormError(err.response?.data?.error || err.message || 'Failed to create event');
    } finally {
      setSavingEvent(false);
    }
  };

  const openAttendanceFromEvent = async () => {
    if (!selectedCalendarEvent) return;
    const date = toDateInput(selectedCalendarEvent.instanceStartAt || selectedCalendarEvent.startAt);
    setAttendanceDate(date);
    setAttendanceError('');
    try {
      const existing = await getEventAttendance(activeClubId, activeTeamId, selectedCalendarEvent.eventId, date).catch(() => []);
      setAttendanceEntries(buildAttendanceEntries(players, existing || []));
      setShowAttendanceForm(true);
    } catch {
      setAttendanceEntries(buildAttendanceEntries(players));
      setShowAttendanceForm(true);
    }
  };

  const handleSaveAttendance = async () => {
    if (!selectedCalendarEvent) return;
    if (attendanceEntries.length === 0) { setAttendanceError('No players found to record attendance for'); return; }
    setAttendanceError('');
    setSavingAttendance(true);
    try {
      await recordAttendance(activeClubId, activeTeamId, selectedCalendarEvent.eventId, {
        instanceDate: attendanceDate,
        records: attendanceEntries.map((entry) => ({
          playerUserId: entry.playerUserId,
          status: entry.status,
          notes: entry.notes || null,
        })),
      });
      setShowAttendanceForm(false);
      await openCalendarEvent(selectedCalendarEvent);
    } catch (err) {
      setAttendanceError(err.response?.data?.error || 'Failed to save attendance');
    } finally {
      setSavingAttendance(false);
    }
  };

  const updateAttendanceEntry = (idx, patch) => {
    setAttendanceEntries((prev) => prev.map((entry, i) => i === idx ? { ...entry, ...patch } : entry));
  };

  if (!activeTeamId) {
    return (
      <PageTransition className="flex-1">
        <TopBar title="Team" />
        <div className="px-4 py-8">
          <EmptyState icon={Users} title="No team selected" subtitle="Create or join a team to see the team hub" />
        </div>
      </PageTransition>
    );
  }

  const orderedSections = access.isAnalyst
    ? ['calendar', 'events', 'stats', 'members']
    : access.isFitnessCoach
      ? ['calendar', 'events', 'fitness', 'members', 'stats']
      : access.isDoctor
        ? ['calendar', 'events', 'medical', 'members']
        : access.isCoach
          ? ['calendar', 'events', 'members', 'plans']
          : access.isPlayer
            ? ['calendar', 'events', 'members', 'announcements', 'stats']
            : ['calendar', 'actions', 'events', 'attendance', 'members', 'announcements', 'stats', 'plans', 'fitness', 'medical'];

  const renderSection = (section) => {
    switch (section) {
      case 'calendar':
        return (
          <Section key="calendar" title="Calendar" icon={Calendar} isDark={isDark} wide>
            <TeamCalendar
              isDark={isDark}
              mode={calendarMode}
              setMode={setCalendarMode}
              anchorDate={calendarDate}
              setAnchorDate={setCalendarDate}
              events={calendarEvents}
              canCreate={access.canManageEvents}
              onSlotClick={handleCalendarSlotClick}
              onEventClick={openCalendarEvent}
            />
          </Section>
        );
      case 'actions':
        return access.isManager ? (
          <Section key="actions" title="Management" icon={Plus} isDark={isDark}>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
              <ActionButton label="Invite Members" onClick={() => navigate('/app/add-members')} />
              <ActionButton label="Create From Calendar" onClick={() => handleCalendarSlotClick(new Date())} />
              <ActionButton label="Announcement" onClick={() => navigate('/app/add-announcement')} />
              <ActionButton label="Stats Entry" onClick={() => navigate('/app/team-stats')} />
            </div>
          </Section>
        ) : null;
      case 'members':
        return (
          <Section key="members" title="Members" icon={Users} isDark={isDark} action={access.isManager ? { label: 'Invite', onClick: () => navigate('/app/add-members') } : null}>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
              {members.length === 0 ? (
                <SoftEmpty text={access.isManager ? 'Invite members to build your roster' : 'Roster details will appear here once members join'} isDark={isDark} />
              ) : (
                members.map((member) => {
                  const locked = access.isPlayer && member.userId !== currentUser?.userId;
                  return (
                    <PlayerCard
                      key={member.userId}
                      member={member}
                      locked={locked}
                      isDark={isDark}
                      medical={medicalByUser.get(member.userId)}
                      fitness={fitnessByUser.get(member.userId)}
                      onClick={() => openMember(member)}
                    />
                  );
                })
              )}
            </div>
          </Section>
        );
      case 'events':
        return (
          <Section key="events" title="Upcoming Schedule" icon={Calendar} isDark={isDark} action={access.canManageEvents ? { label: 'Add Event', onClick: () => navigate('/app/add-event') } : { label: 'View Events', onClick: () => navigate('/app/events') }}>
            {upcoming.length === 0 ? <SoftEmpty text="No upcoming events" isDark={isDark} /> : (
              <div className="space-y-2">
                {upcoming.map((event) => (
                  <div key={event.eventId} className={`p-3 rounded-card ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
                    <div className="flex items-center justify-between gap-3">
                      <p className={`font-semibold text-sm ${isDark ? 'text-white' : 'text-black'}`}>{event.title || event.eventType}</p>
                      <span className="text-xs px-2 py-0.5 rounded-pill bg-primary/10 text-primary">{eventDate(event.startAt)}</span>
                    </div>
                    <p className={`text-xs mt-1 ${isDark ? 'text-white/50' : 'text-gray-500'}`}>{event.eventType}{event.location ? ` - ${event.location}` : ''}</p>
                  </div>
                ))}
              </div>
            )}
          </Section>
        );
      case 'announcements':
        return (
          <Section key="announcements" title="Announcements" icon={Megaphone} isDark={isDark} action={access.canManageAnnouncements ? { label: 'Add', onClick: () => navigate('/app/add-announcement') } : null}>
            {announcements.length === 0 ? <SoftEmpty text="No announcements yet" isDark={isDark} /> : announcements.slice(0, 4).map((a) => (
              <div key={a.announcementId} className={`p-3 rounded-card mb-2 ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
                <p className={`font-semibold text-sm ${isDark ? 'text-white' : 'text-black'}`}>{a.title}</p>
                <p className={`text-xs mt-1 ${isDark ? 'text-white/55' : 'text-gray-600'}`}>{a.content}</p>
              </div>
            ))}
          </Section>
        );
      case 'attendance':
        return access.canManageAttendance ? (
          <Section key="attendance" title="Attendance" icon={ClipboardCheck} isDark={isDark} action={{ label: 'View Attendance', onClick: () => navigate('/app/events') }}>
            <p className={`text-sm ${isDark ? 'text-white/55' : 'text-gray-600'}`}>Take attendance from the event cards. Team managers keep the records scoped to this team.</p>
          </Section>
        ) : null;
      case 'stats':
        return access.canViewStats ? (
          <Section key="stats" title="Stats" icon={BarChart3} isDark={isDark} action={access.canEnterStats ? { label: 'Enter Stats', onClick: () => navigate('/app/team-stats') } : { label: 'View Stats', onClick: () => navigate('/app/team-stats') }}>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-2 mb-3">
              <Metric label="Events" value={teamStats?.totalEvents ?? 0} isDark={isDark} />
              <Metric label="Wins" value={teamStats?.wins ?? 0} isDark={isDark} />
              <Metric label="Goals" value={teamStats?.totalGoals ?? 0} isDark={isDark} />
              <Metric label="Matches" value={matchHistory.length} isDark={isDark} />
            </div>
            <div className="flex gap-1.5 mb-2">
              {['goals', 'assists', 'rating'].map((item) => (
                <button key={item} onClick={() => setLeaderboardSort(item)}
                  className={`px-2.5 py-1 rounded-pill text-[11px] font-semibold capitalize ${leaderboardSort === item ? 'bg-primary text-white' : isDark ? 'bg-white/10 text-white/50' : 'bg-gray-100 text-gray-500'}`}>
                  {item}
                </button>
              ))}
            </div>
            {sortedLeaderboard.slice(0, 5).map((player, index) => (
              <button key={player.playerUserId} onClick={() => navigate(`/app/members/${player.playerUserId}?tab=stats`)}
                className={`w-full flex items-center justify-between p-2 rounded-card mb-1 text-left ${isDark ? 'hover:bg-white/5' : 'hover:bg-gray-50'}`}>
                <span className={`text-sm font-semibold ${isDark ? 'text-white' : 'text-black'}`}>#{index + 1} {player.playerName}</span>
                <span className="text-xs text-primary">{player.goals} G / {player.assists} A</span>
              </button>
            ))}
          </Section>
        ) : null;
      case 'plans':
        return access.canViewPlans ? (
          <Section key="plans" title="Plans and Lineups" icon={FileText} isDark={isDark} action={{ label: 'View Plans', onClick: () => navigate('/app/plans') }}>
            <div className="grid grid-cols-2 gap-2">
              <Metric label="Plans" value={plans.length} isDark={isDark} />
              <Metric label="Lineups" value={lineups.length} isDark={isDark} />
            </div>
          </Section>
        ) : null;
      case 'fitness':
        return (access.isFitnessCoach || access.isManager) ? (
          <Section key="fitness" title="Fitness" icon={Activity} isDark={isDark}>
            {fitnessSummary.length === 0 ? <SoftEmpty text="Open a player profile to log fitness records" isDark={isDark} /> : fitnessSummary.slice(0, 6).map(({ player, latest, count }) => (
              <PlayerSummary key={player.userId} player={player} title={latest ? new Date(latest.testDate).toLocaleDateString() : 'No records'} subtitle={`${count} fitness record${count === 1 ? '' : 's'}`} onClick={() => navigate(`/app/members/${player.userId}?tab=fitness`)} isDark={isDark} />
            ))}
          </Section>
        ) : null;
      case 'medical':
        return (access.isDoctor || access.isManager) ? (
          <Section key="medical" title="Medical Clearance" icon={HeartPulse} isDark={isDark}>
            {medicalSummary.length === 0 ? <SoftEmpty text="Open a player profile to manage medical records" isDark={isDark} /> : medicalSummary.slice(0, 6).map(({ player, latest, pending }) => (
              <PlayerSummary key={player.userId} player={player} title={latest?.isCleared ? 'Cleared' : latest ? 'Not cleared' : 'No record'} subtitle={pending ? `${pending} pending document request${pending === 1 ? '' : 's'}` : latest?.injuryType || 'Medical profile'} onClick={() => navigate(`/app/members/${player.userId}?tab=medical`)} isDark={isDark} statusIcon={ShieldCheck} />
            ))}
          </Section>
        ) : null;
      default:
        return null;
    }
  };

  return (
    <PageTransition className="flex-1">
      <TopBar title="Team Hub" />
      <div className="px-4 md:px-6 lg:px-8 pb-24 lg:pb-8 max-w-7xl mx-auto w-full">
        <div className={`p-5 rounded-card shadow-sm mb-4 ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
          <div className={`text-xs mb-3 ${isDark ? 'text-white/40' : 'text-gray-500'}`}>
            Home / {selectedTeam?.teamName || 'Team'} / Hub
          </div>
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="text-xs font-semibold text-primary uppercase">Active team</p>
              <h2 className={`text-xl md:text-2xl font-bold mt-1 ${isDark ? 'text-white' : 'text-black'}`}>{selectedTeam?.teamName || 'Selected team'}</h2>
              <p className={`text-sm mt-1 ${isDark ? 'text-white/50' : 'text-gray-500'}`}>{players.length} players - {members.length} total members</p>
            </div>
            <Trophy className="text-primary" size={28} />
          </div>
        </div>

        {loading && <div className="flex justify-center py-8"><LoadingSpinner /></div>}
        {error && <div className="p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{error}</div>}
        {!loading && !error && (
          <>
            <TeamStatsHero isDark={isDark} data={teamHero} selectedTeam={selectedTeam} isPlayer={access.isPlayer} onProfile={() => navigate('/app/profile')} />
            <div className="grid grid-cols-1 xl:grid-cols-2 gap-4 mt-4">
              {orderedSections.map(renderSection)}
            </div>
          </>
        )}
      </div>

      <SlidePanel isOpen={!!selectedCalendarEvent} onClose={() => setSelectedCalendarEvent(null)} title={selectedCalendarEvent?.title || 'Event'} isDark={isDark}>
        {eventDetailLoading && <div className="flex justify-center py-8"><LoadingSpinner /></div>}
        {!eventDetailLoading && selectedCalendarEvent && (
          <div className="space-y-3">
            <div className={`p-3 rounded-card ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
              <div className="flex items-center justify-between gap-3">
                <span className={`text-sm font-semibold ${isDark ? 'text-white' : 'text-black'}`}>{selectedCalendarEvent.eventType}</span>
                <span className={`text-xs px-2 py-0.5 rounded-pill ${eventTypeClasses(selectedCalendarEvent.eventType)}`}>
                  {formatEventTime(selectedCalendarEvent.instanceStartAt || selectedCalendarEvent.startAt)}
                </span>
              </div>
              <p className={`text-xs mt-2 ${isDark ? 'text-white/55' : 'text-gray-600'}`}>
                {new Date(selectedCalendarEvent.instanceStartAt || selectedCalendarEvent.startAt).toLocaleString()}
                {selectedCalendarEvent.endAt ? ` - ${new Date(selectedCalendarEvent.instanceEndAt || selectedCalendarEvent.endAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}` : ''}
              </p>
              {selectedCalendarEvent.location && <p className={`text-xs mt-1 ${isDark ? 'text-white/45' : 'text-gray-500'}`}>{selectedCalendarEvent.location}</p>}
              {selectedCalendarEvent.description && <p className={`text-xs mt-2 ${isDark ? 'text-white/60' : 'text-gray-600'}`}>{selectedCalendarEvent.description}</p>}
              {selectedCalendarEvent.isCancelled && <p className="text-xs mt-2 text-red-500">Cancelled event instance</p>}
              {selectedCalendarEvent.isRescheduled && <p className="text-xs mt-2 text-yellow-500">Rescheduled event instance</p>}
            </div>

            {access.canManageAttendance && eventAttendance.length > 0 && (
              <div className={`p-3 rounded-card ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
                <div className="flex items-center gap-3">
                  <ProgressRing value={attendanceRate(eventAttendance)} />
                  <div className="flex-1">
                    <h4 className={`text-sm font-semibold mb-2 ${isDark ? 'text-white' : 'text-black'}`}>Attendance Summary</h4>
                    <div className="flex gap-1.5 flex-wrap">
                      {ATTENDANCE_STATUSES.map((status) => (
                        <span key={status} className="text-xs px-2 py-0.5 rounded-pill bg-primary/10 text-primary">
                          {status}: {eventAttendance.filter((row) => row.status === status).length}
                        </span>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            )}

            {access.isPlayer && eventAttendance[0] && (
              <div className={`p-3 rounded-card ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
                <p className={`text-xs ${isDark ? 'text-white/45' : 'text-gray-500'}`}>Your attendance</p>
                <p className={`text-sm font-semibold mt-1 ${isDark ? 'text-white' : 'text-black'}`}>{eventAttendance[0].status}</p>
              </div>
            )}

            {eventStats && (
              <div className={`p-3 rounded-card ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
                <h4 className={`text-sm font-semibold mb-2 ${isDark ? 'text-white' : 'text-black'}`}>Linked Stats</h4>
                <div className="grid grid-cols-2 gap-2">
                  <Metric label="Score" value={`${eventStats.teamScore ?? '-'}-${eventStats.opponentScore ?? '-'}`} isDark={isDark} />
                  <Metric label="Result" value={eventStats.result || '-'} isDark={isDark} />
                </div>
              </div>
            )}

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              {access.canManageAttendance && isPastEvent(selectedCalendarEvent) && (
                <button onClick={openAttendanceFromEvent} className="flex items-center justify-center gap-2 py-2.5 rounded-card bg-primary text-white text-sm font-semibold">
                  <ClipboardCheck size={15} />Mark Attendance
                </button>
              )}
              {access.isAnalyst && selectedCalendarEvent.eventType === 'Match' && isPastEvent(selectedCalendarEvent) && (
                <button onClick={() => navigate(`/app/team-stats?eventId=${selectedCalendarEvent.eventId}&tab=Entry`)} className="flex items-center justify-center gap-2 py-2.5 rounded-card bg-primary text-white text-sm font-semibold">
                  <BarChart3 size={15} />Enter Stats
                </button>
              )}
              <button onClick={() => setSelectedCalendarEvent(null)} className={`flex items-center justify-center gap-2 py-2.5 rounded-card text-sm font-semibold ${isDark ? 'bg-white/10 text-white' : 'bg-gray-100 text-gray-700'}`}>
                <Eye size={15} />Close
              </button>
            </div>
          </div>
        )}
      </SlidePanel>

      <SlidePanel isOpen={showAttendanceForm} onClose={() => setShowAttendanceForm(false)} title="Record Attendance" isDark={isDark}>
        <div className="flex flex-col gap-3">
          {attendanceError && <div className="p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{attendanceError}</div>}
          <input
            type="date"
            value={attendanceDate}
            onChange={(event) => setAttendanceDate(event.target.value)}
            className={`w-full px-4 py-3 rounded-card border-2 text-body outline-none transition-colors ${isDark ? 'bg-surface-dark text-white border-accent/50 focus:border-accent' : 'bg-white text-black border-accent/50 focus:border-accent'}`}
          />
          <div className="max-h-[50vh] overflow-y-auto space-y-2">
            {attendanceEntries.map((entry, idx) => (
              <div key={entry.playerUserId} className={`p-3 rounded-card ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
                <div className="flex items-center justify-between gap-2 mb-2">
                  <button onClick={() => navigate(`/app/members/${entry.playerUserId}?tab=attendance`)} className={`text-sm font-semibold text-left hover:text-primary ${isDark ? 'text-white' : 'text-black'}`}>{entry.playerName}</button>
                  <SelectField label="Status" value={entry.status} onChange={(status) => updateAttendanceEntry(idx, { status })} options={ATTENDANCE_STATUSES} />
                </div>
                <input
                  value={entry.notes}
                  onChange={(event) => updateAttendanceEntry(idx, { notes: event.target.value })}
                  placeholder="Notes"
                  className={`w-full px-3 py-2 rounded-card border text-xs outline-none transition-colors ${isDark ? 'bg-surface-dark border-white/10 text-white placeholder:text-white/30' : 'bg-white border-gray-200 text-black placeholder:text-gray-400'}`}
                />
              </div>
            ))}
          </div>
          <button onClick={handleSaveAttendance} disabled={savingAttendance || attendanceEntries.length === 0}
            className="w-full py-3 rounded-card bg-primary text-white font-semibold hover:bg-primary-dark transition-colors disabled:opacity-60">
            {savingAttendance ? 'Saving...' : 'Save Attendance'}
          </button>
        </div>
      </SlidePanel>

      <SlidePanel isOpen={showEventForm} onClose={() => setShowEventForm(false)} title="Create Event" isDark={isDark}>
        <div className="flex flex-col gap-3">
          {eventFormError && <div className="p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{eventFormError}</div>}
          <FormInput label="Title *" value={eventForm.title} onChange={(e) => setEventForm({ ...eventForm, title: e.target.value })} />
          <SelectField label="Type *" value={eventForm.eventType} onChange={(eventType) => setEventForm({ ...eventForm, eventType })} options={['Match', 'Training', 'Meeting', 'Test']} />
          <FormInput label="Start *" type="datetime-local" value={eventForm.startAt} onChange={(e) => setEventForm({ ...eventForm, startAt: e.target.value })} />
          <FormInput label="End" type="datetime-local" value={eventForm.endAt} onChange={(e) => setEventForm({ ...eventForm, endAt: e.target.value })} />
          <FormInput label="Location" value={eventForm.location} onChange={(e) => setEventForm({ ...eventForm, location: e.target.value })} />
          <FormInput label="Description" value={eventForm.description} onChange={(e) => setEventForm({ ...eventForm, description: e.target.value })} />
          <button onClick={handleSaveEvent} disabled={savingEvent}
            className="w-full py-3 rounded-card bg-primary text-white font-semibold hover:bg-primary-dark transition-colors disabled:opacity-60">
            {savingEvent ? 'Creating...' : 'Create Event'}
          </button>
        </div>
      </SlidePanel>
    </PageTransition>
  );
}

function Section({ title, icon: Icon, isDark, action, children, wide = false }) {
  const sectionId = `team-section-${title.toLowerCase().split(' ')[0]}`;
  return (
    <section id={sectionId} className={`p-4 rounded-card shadow-sm ${wide ? 'xl:col-span-2' : ''} ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
      <div className="flex items-center justify-between gap-3 mb-3">
        <div className="flex items-center gap-2">
          <Icon size={18} className="text-primary" />
          <h3 className={`font-semibold ${isDark ? 'text-white' : 'text-black'}`}>{title}</h3>
        </div>
        {action && (
          <button onClick={action.onClick} className="px-3 py-1.5 rounded-card bg-primary text-white text-xs font-semibold">
            {action.label}
          </button>
        )}
      </div>
      {children}
    </section>
  );
}

function TeamStatsHero({ isDark, data, selectedTeam, isPlayer, onProfile }) {
  return (
    <section className={`overflow-hidden rounded-card shadow-sm ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
      <div className="p-4 md:p-5">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-4">
          <div>
            <p className="text-xs font-semibold text-primary uppercase">Team overview</p>
            <h2 className={`text-xl md:text-2xl font-bold mt-1 ${isDark ? 'text-white' : 'text-black'}`}>{selectedTeam?.teamName || 'Team'} stats pulse</h2>
            <p className={`text-sm mt-1 ${isDark ? 'text-white/50' : 'text-gray-500'}`}>{data.record} record - {data.winRate}% win rate</p>
          </div>
          {isPlayer && (
            <button onClick={onProfile} className="px-4 py-2 rounded-card bg-primary text-white text-sm font-semibold">
              My Dashboard
            </button>
          )}
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 xl:grid-cols-6 gap-2 md:gap-3">
          <HeroMetric label="Matches" value={data.matches} isDark={isDark} />
          <HeroMetric label="Goals" value={data.goals} isDark={isDark} accent />
          <HeroMetric label="Conceded" value={data.conceded} isDark={isDark} />
          <HeroMetric label="Win Rate" value={data.winRate} suffix="%" isDark={isDark} />
          <HeroMetric label="Top Scorer" value={data.topScorerGoals} suffix=" G" sub={data.topScorerName} isDark={isDark} />
          <HeroMetric label="Top Assist" value={data.topAssistCount} suffix=" A" sub={data.topAssistName} isDark={isDark} />
        </div>

        <div className={`mt-4 p-3 rounded-card ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
          <div className="flex items-center justify-between gap-3 mb-2">
            <span className={`text-xs font-semibold ${isDark ? 'text-white/60' : 'text-gray-500'}`}>Momentum</span>
            <span className="text-xs font-semibold text-primary">Avg rating {data.averageRating || '-'}</span>
          </div>
          <div className={`h-2 rounded-full overflow-hidden ${isDark ? 'bg-white/10' : 'bg-gray-200'}`}>
            <div className="h-full rounded-full bg-primary transition-all duration-700" style={{ width: `${Math.min(100, data.winRate)}%` }} />
          </div>
          {isPlayer && data.myGoals > 0 && (
            <p className={`text-xs mt-2 ${isDark ? 'text-white/50' : 'text-gray-500'}`}>You scored {data.myGoals} of these goals.</p>
          )}
        </div>
      </div>
    </section>
  );
}

function HeroMetric({ label, value, suffix = '', sub, isDark, accent = false }) {
  return (
    <div className={`p-3 rounded-card ${accent ? 'bg-primary text-white' : isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
      <p className={`text-[11px] font-semibold uppercase ${accent ? 'text-white/75' : isDark ? 'text-white/40' : 'text-gray-500'}`}>{label}</p>
      <p className={`text-2xl font-black mt-1 ${accent ? 'text-white' : isDark ? 'text-white' : 'text-black'}`}>
        {typeof value === 'number' ? <AnimatedNumber value={value} /> : value}{suffix}
      </p>
      {sub && <p className={`text-xs truncate mt-1 ${accent ? 'text-white/75' : isDark ? 'text-white/45' : 'text-gray-500'}`}>{sub}</p>}
    </div>
  );
}

function AnimatedNumber({ value }) {
  const [display, setDisplay] = useState(0);
  useEffect(() => {
    let frame;
    const start = performance.now();
    const duration = 650;
    const tick = (now) => {
      const progress = Math.min(1, (now - start) / duration);
      setDisplay(Math.round(value * progress));
      if (progress < 1) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [value]);
  return display;
}

function PlayerCard({ member, locked, isDark, medical, fitness, onClick }) {
  const isPlayer = member.role === 'Player';
  const clearance = medical?.latest ? (medical.latest.isCleared ? 'Cleared' : 'Review') : 'Unknown';
  const fitnessScore = fitness?.latest ? latestFitnessScore(fitness.latest) : null;

  return (
    <button onClick={onClick} disabled={locked}
      className={`relative overflow-hidden p-3 rounded-card text-left transition-all hover:-translate-y-0.5 ${isDark ? 'bg-surface-darkest hover:bg-white/5' : 'bg-gray-50 hover:bg-gray-100'} ${locked ? 'opacity-70 cursor-default' : ''}`}>
      <div className="flex items-start gap-3">
        <Avatar alt={member.name} size="md" />
        <div className="flex-1 min-w-0">
          <div className="flex items-center justify-between gap-2">
            <p className={`font-semibold text-sm truncate ${isDark ? 'text-white' : 'text-black'}`}>{member.name}</p>
            {member.jerseyNumber != null && <span className="text-lg font-black text-primary">#{member.jerseyNumber}</span>}
          </div>
          <div className="flex flex-wrap gap-1.5 mt-1">
            <span className="text-[10px] px-2 py-0.5 rounded-pill bg-primary/10 text-primary">{member.position || roleLabel(member.role)}</span>
            {isPlayer && <span className={`text-[10px] px-2 py-0.5 rounded-pill ${clearance === 'Cleared' ? 'bg-green-500/10 text-green-500' : clearance === 'Review' ? 'bg-red-500/10 text-red-500' : 'bg-yellow-500/10 text-yellow-500'}`}>{clearance}</span>}
            {locked && <span className={`text-[10px] px-2 py-0.5 rounded-pill ${isDark ? 'bg-white/10 text-white/50' : 'bg-gray-200 text-gray-500'}`}>Private</span>}
          </div>
          {isPlayer && fitnessScore != null && (
            <div className="mt-2">
              <div className={`h-1.5 rounded-full overflow-hidden ${isDark ? 'bg-white/10' : 'bg-gray-200'}`}>
                <div className="h-full bg-primary rounded-full" style={{ width: `${Math.min(100, fitnessScore)}%` }} />
              </div>
              <p className={`text-[10px] mt-1 ${isDark ? 'text-white/35' : 'text-gray-400'}`}>Fitness {fitnessScore}</p>
            </div>
          )}
        </div>
      </div>
    </button>
  );
}

function ProgressRing({ value }) {
  const radius = 18;
  const circumference = 2 * Math.PI * radius;
  const offset = circumference - (value / 100) * circumference;
  return (
    <div className="relative w-12 h-12 flex-shrink-0">
      <svg className="w-12 h-12 -rotate-90" viewBox="0 0 44 44">
        <circle cx="22" cy="22" r={radius} stroke="currentColor" strokeWidth="4" fill="none" className="text-gray-300/30" />
        <circle cx="22" cy="22" r={radius} stroke="currentColor" strokeWidth="4" fill="none" strokeDasharray={circumference} strokeDashoffset={offset} className="text-primary transition-all duration-700" strokeLinecap="round" />
      </svg>
      <span className="absolute inset-0 flex items-center justify-center text-[10px] font-bold text-primary">{value}%</span>
    </div>
  );
}

function SlidePanel({ isOpen, onClose, title, isDark, children }) {
  if (!isOpen) return null;
  return (
    <div className="fixed inset-0 z-50">
      <button className="absolute inset-0 bg-black/40" onClick={onClose} aria-label="Close panel" />
      <aside className={`absolute bottom-0 left-0 right-0 md:left-auto md:top-0 md:h-full md:w-[440px] max-h-[88vh] md:max-h-none overflow-y-auto rounded-t-2xl md:rounded-none p-4 shadow-2xl animate-slide-up ${isDark ? 'bg-surface-dark text-white' : 'bg-white text-black'}`}>
        <div className="flex items-center justify-between gap-3 mb-4">
          <h3 className="font-semibold text-lg">{title}</h3>
          <button onClick={onClose} className={`p-2 rounded-full ${isDark ? 'hover:bg-white/10' : 'hover:bg-gray-100'}`}><X size={18} /></button>
        </div>
        {children}
      </aside>
    </div>
  );
}

function TeamCalendar({ isDark, mode, setMode, anchorDate, setAnchorDate, events, canCreate, onSlotClick, onEventClick }) {
  const days = buildCalendarDays(anchorDate, mode);
  const title = calendarTitle(anchorDate, mode);

  const move = (direction) => {
    const next = new Date(anchorDate);
    if (mode === 'Month') next.setMonth(next.getMonth() + direction);
    if (mode === 'Week') next.setDate(next.getDate() + direction * 7);
    if (mode === 'Day') next.setDate(next.getDate() + direction);
    setAnchorDate(next);
  };

  return (
    <div>
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3 mb-3">
        <div className="flex items-center gap-2">
          <button onClick={() => move(-1)} className={`p-2 rounded-full ${isDark ? 'hover:bg-white/10 text-white' : 'hover:bg-gray-100 text-black'}`}><ChevronLeft size={18} /></button>
          <h4 className={`font-semibold min-w-[180px] text-center ${isDark ? 'text-white' : 'text-black'}`}>{title}</h4>
          <button onClick={() => move(1)} className={`p-2 rounded-full ${isDark ? 'hover:bg-white/10 text-white' : 'hover:bg-gray-100 text-black'}`}><ChevronRight size={18} /></button>
        </div>
        <div className="flex gap-2 overflow-x-auto">
          {CALENDAR_MODES.map((item) => (
            <button key={item} onClick={() => setMode(item)}
              className={`px-3 py-1.5 rounded-pill text-xs font-semibold transition-colors ${mode === item ? 'bg-primary text-white' : isDark ? 'bg-white/10 text-white/60' : 'bg-gray-100 text-gray-600'}`}>
              {item}
            </button>
          ))}
        </div>
      </div>

      {mode === 'Month' && (
        <div className="grid grid-cols-7 gap-1 mb-1">
          {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((day) => (
            <div key={day} className={`text-center text-[11px] font-semibold py-1 ${isDark ? 'text-white/40' : 'text-gray-400'}`}>{day}</div>
          ))}
        </div>
      )}

      <div className={`grid gap-1 ${mode === 'Month' ? 'grid-cols-7' : mode === 'Week' ? 'grid-cols-1 md:grid-cols-7' : 'grid-cols-1'}`}>
        {days.map((day) => {
          const dayEvents = events.filter((event) => sameDate(event.instanceStartAt || event.startAt, day.date));
          const isMuted = mode === 'Month' && day.date.getMonth() !== anchorDate.getMonth();
          return (
            <button key={day.key} onClick={() => dayEvents.length === 0 ? onSlotClick(day.date) : null}
              className={`min-h-[112px] p-2 rounded-card border text-left transition-colors ${canCreate && dayEvents.length === 0 ? 'cursor-pointer' : 'cursor-default'} ${isDark ? 'border-white/10 bg-surface-darkest hover:bg-white/5' : 'border-gray-100 bg-gray-50 hover:bg-gray-100'} ${isMuted ? 'opacity-45' : ''}`}>
              <div className="flex items-center justify-between mb-2">
                <span className={`text-xs font-semibold ${isDark ? 'text-white/60' : 'text-gray-500'}`}>{mode === 'Day' ? day.date.toLocaleDateString([], { weekday: 'long', month: 'short', day: 'numeric' }) : day.date.getDate()}</span>
                {canCreate && dayEvents.length === 0 && <Plus size={13} className="text-primary" />}
              </div>
              <div className="space-y-1">
                {dayEvents.slice(0, mode === 'Month' ? 3 : 8).map((event) => (
                  <div key={event.calendarKey} onClick={(click) => { click.stopPropagation(); onEventClick(event); }}
                    title={`${event.title || event.eventType} - ${formatEventTime(event.instanceStartAt || event.startAt)} - ${event.eventType}`}
                    className={`p-2 rounded-card text-xs transition-transform hover:scale-[1.01] ${eventTypeClasses(event.eventType)} ${event.isCancelled ? 'opacity-50 line-through grayscale' : ''}`}>
                    <div className="font-semibold truncate">{event.title || event.eventType}{event.isRescheduled ? ' - Rescheduled' : ''}</div>
                    <div className="opacity-80 truncate">{event.eventType} - {formatEventTime(event.instanceStartAt || event.startAt)}</div>
                  </div>
                ))}
                {dayEvents.length > (mode === 'Month' ? 3 : 8) && (
                  <span className={`text-[10px] ${isDark ? 'text-white/40' : 'text-gray-500'}`}>+{dayEvents.length - (mode === 'Month' ? 3 : 8)} more</span>
                )}
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}

function ActionButton({ label, onClick }) {
  return <button onClick={onClick} className="px-3 py-3 rounded-card bg-primary/10 text-primary text-sm font-semibold hover:bg-primary/20 transition-colors">{label}</button>;
}

function Metric({ label, value, isDark }) {
  return (
    <div className={`p-3 rounded-card ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
      <p className={`text-xs ${isDark ? 'text-white/40' : 'text-gray-500'}`}>{label}</p>
      <p className={`text-lg font-bold ${isDark ? 'text-white' : 'text-black'}`}>{value}</p>
    </div>
  );
}

function PlayerSummary({ player, title, subtitle, onClick, isDark }) {
  return (
    <button onClick={onClick} className={`w-full flex items-center gap-3 p-3 rounded-card mb-2 text-left transition-colors ${isDark ? 'bg-surface-darkest hover:bg-white/5' : 'bg-gray-50 hover:bg-gray-100'}`}>
      <Avatar alt={player.name} size="sm" />
      <div className="flex-1 min-w-0">
        <p className={`text-sm font-semibold truncate ${isDark ? 'text-white' : 'text-black'}`}>{player.name}</p>
        <p className={`text-xs truncate ${isDark ? 'text-white/45' : 'text-gray-500'}`}>{subtitle}</p>
      </div>
      <span className="text-xs font-semibold text-primary">{title}</span>
    </button>
  );
}

function SoftEmpty({ text, isDark }) {
  return <p className={`text-sm py-2 ${isDark ? 'text-white/45' : 'text-gray-500'}`}>{text}</p>;
}

function buildCalendarDays(anchorDate, mode) {
  if (mode === 'Day') {
    return [{ key: toDateInput(anchorDate), date: startOfDay(anchorDate) }];
  }

  const start = mode === 'Week' ? startOfWeek(anchorDate) : startOfWeek(new Date(anchorDate.getFullYear(), anchorDate.getMonth(), 1));
  const count = mode === 'Week' ? 7 : 42;
  return Array.from({ length: count }, (_, index) => {
    const date = new Date(start);
    date.setDate(start.getDate() + index);
    return { key: toDateInput(date), date };
  });
}

function calendarTitle(date, mode) {
  if (mode === 'Day') return date.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' });
  if (mode === 'Week') {
    const start = startOfWeek(date);
    const end = new Date(start);
    end.setDate(start.getDate() + 6);
    return `${start.toLocaleDateString([], { month: 'short', day: 'numeric' })} - ${end.toLocaleDateString([], { month: 'short', day: 'numeric' })}`;
  }
  return date.toLocaleDateString([], { month: 'long', year: 'numeric' });
}

function expandCalendarEvents(events, anchorDate, mode) {
  const days = buildCalendarDays(anchorDate, mode);
  const rangeStart = days[0].date;
  const rangeEnd = days[days.length - 1].date;
  rangeEnd.setHours(23, 59, 59, 999);

  return (events || []).flatMap((event) => expandEventInstances(event, rangeStart, rangeEnd));
}

function expandEventInstances(event, rangeStart, rangeEnd) {
  if (!event.recurrenceRule) return [withException(event, new Date(event.startAt))].filter(Boolean);

  const rule = parseRecurrenceRule(event.recurrenceRule);
  const until = event.recurrenceEndDate ? new Date(event.recurrenceEndDate) : rangeEnd;
  const original = new Date(event.startAt);
  const instances = [];

  for (let day = startOfDay(rangeStart); day <= until && day <= rangeEnd; day.setDate(day.getDate() + 1)) {
    if (day < startOfDay(original)) continue;
    if (rule.freq !== 'DAILY') {
      const allowedDays = rule.byday?.length ? rule.byday : [original.getDay()];
      if (!allowedDays.includes(day.getDay())) continue;
    }
    const current = new Date(day);
    current.setHours(original.getHours(), original.getMinutes(), original.getSeconds(), original.getMilliseconds());
    const instance = withException(event, current);
    if (instance) instances.push(instance);
  }

  return instances;
}

function withException(event, instanceStart) {
  const originalDate = toDateInput(instanceStart);
  const exception = (event.exceptions || []).find((item) => String(item.originalDate).slice(0, 10) === originalDate);
  const duration = event.endAt ? new Date(event.endAt).getTime() - new Date(event.startAt).getTime() : 0;
  const start = exception?.newStartAt ? new Date(exception.newStartAt) : instanceStart;
  const end = exception?.newEndAt ? new Date(exception.newEndAt) : duration > 0 ? new Date(start.getTime() + duration) : null;

  return {
    ...event,
    calendarKey: `${event.eventId}-${originalDate}-${exception?.eventExceptionId || 'base'}`,
    instanceStartAt: start.toISOString(),
    instanceEndAt: end?.toISOString(),
    isCancelled: Boolean(exception?.isCancelled),
    isRescheduled: Boolean(exception?.newStartAt),
    exceptionNotes: exception?.notes,
  };
}

function parseRecurrenceRule(rule) {
  const parts = Object.fromEntries(String(rule).split(';').map((part) => {
    const [key, value] = part.split('=');
    return [key?.toLowerCase(), value];
  }));
  const dayMap = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 };
  return {
    freq: String(parts.freq || 'WEEKLY').toUpperCase(),
    byday: parts.byday ? String(parts.byday).split(',').map((day) => dayMap[day]).filter((day) => day !== undefined) : null,
  };
}

function startOfWeek(date) {
  const result = startOfDay(date);
  result.setDate(result.getDate() - result.getDay());
  return result;
}

function startOfDay(date) {
  const result = new Date(date);
  result.setHours(0, 0, 0, 0);
  return result;
}

function sameDate(value, date) {
  return toDateInput(value) === toDateInput(date);
}

function toDateInput(value) {
  const date = new Date(value);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function toDateTimeLocal(value) {
  const date = new Date(value);
  return `${toDateInput(date)}T${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

function setTime(date, hours, minutes) {
  const next = new Date(date);
  next.setHours(hours, minutes, 0, 0);
  return next;
}

function formatEventTime(value) {
  return new Date(value).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

function isPastEvent(event) {
  return new Date(event.instanceStartAt || event.startAt) <= new Date();
}

function buildAttendanceEntries(players, existingAttendance = []) {
  const byPlayer = new Map((existingAttendance || []).map((item) => [item.playerUserId, item]));
  return players.map((player) => {
    const existing = byPlayer.get(player.userId);
    return {
      playerUserId: player.userId,
      playerName: player.name,
      status: existing?.status || 'Present',
      notes: existing?.notes || '',
    };
  });
}

function attendanceRate(rows) {
  if (!rows?.length) return 0;
  const positive = rows.filter((row) => row.status === 'Present' || row.status === 'Late').length;
  return Math.round((positive / rows.length) * 100);
}

function buildTeamHero(teamStats, matchHistory, currentUserId) {
  const leaderboard = teamStats?.playerLeaderboard || [];
  const topScorer = [...leaderboard].sort((a, b) => (b.goals || 0) - (a.goals || 0))[0];
  const topAssist = [...leaderboard].sort((a, b) => (b.assists || 0) - (a.assists || 0))[0];
  const ratedPlayers = leaderboard.filter((p) => p.averageRating != null);
  const wins = teamStats?.wins || 0;
  const draws = teamStats?.draws || 0;
  const losses = teamStats?.losses || 0;
  const matches = teamStats?.matches || matchHistory?.length || 0;
  const myStats = leaderboard.find((p) => p.playerUserId === currentUserId);

  return {
    record: `${wins}-${draws}-${losses}`,
    matches,
    goals: teamStats?.totalGoals || 0,
    conceded: (matchHistory || []).reduce((sum, item) => sum + (item.opponentScore || 0), 0),
    winRate: matches ? Math.round((wins / matches) * 100) : 0,
    topScorerName: topScorer?.playerName || 'No scorer yet',
    topScorerGoals: topScorer?.goals || 0,
    topAssistName: topAssist?.playerName || 'No assists yet',
    topAssistCount: topAssist?.assists || 0,
    averageRating: ratedPlayers.length ? (ratedPlayers.reduce((sum, p) => sum + Number(p.averageRating || 0), 0) / ratedPlayers.length).toFixed(1) : null,
    myGoals: myStats?.goals || 0,
  };
}

function latestFitnessScore(record) {
  const values = [record.enduranceScore, record.speedTestResult, record.customTestResult, record.bmi]
    .filter((value) => value != null)
    .map(Number)
    .filter((value) => Number.isFinite(value));
  if (!values.length) return null;
  return Math.max(0, Math.min(100, Math.round(values[0])));
}

function sortLeaderboard(players, sortKey) {
  return [...players].sort((a, b) => {
    if (sortKey === 'assists') return (b.assists || 0) - (a.assists || 0);
    if (sortKey === 'rating') return Number(b.averageRating || 0) - Number(a.averageRating || 0);
    return (b.goals || 0) - (a.goals || 0);
  });
}

function eventTypeClasses(type) {
  if (type === 'Match') return 'bg-primary text-white';
  if (type === 'Training') return 'bg-green-600 text-white';
  if (type === 'Meeting') return 'bg-blue-500 text-white';
  if (type === 'Test') return 'bg-[#082E6F] text-white';
  return 'bg-gray-500 text-white';
}
