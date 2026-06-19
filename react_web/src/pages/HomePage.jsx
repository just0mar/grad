import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { staggerContainer, staggerItem } from '../animations/variants';
import TopBar from '../components/TopBar';
import TeamCard from '../components/TeamCard';
import EventCard from '../components/EventCard';
import PageTransition from '../components/PageTransition';
import LoadingSpinner from '../components/LoadingSpinner';
import EmptyState from '../components/EmptyState';
import useTheme from '../hooks/useTheme';
import useClub from '../hooks/useClub';
import useAuth from '../hooks/useAuth';
import { getTeamEvents } from '../services/eventService';
import { getTeamAnnouncements } from '../services/announcementService';
import { Building2, Calendar, Megaphone } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { getRoleAccess } from '../utils/roleAccess';

export default function HomePage() {
  const { isDark } = useTheme();
  const navigate = useNavigate();
  const { clubs, teams, activeClubId, activeTeamId, selectTeam, loading: clubLoading } = useClub();
  const { currentUser, isAdmin } = useAuth();
  const access = getRoleAccess(currentUser, isAdmin);
  const [events, setEvents] = useState([]);
  const [eventsLoading, setEventsLoading] = useState(false);
  const [announcements, setAnnouncements] = useState([]);

  // Fetch events when active team changes
  useEffect(() => {
    if (!activeClubId || !activeTeamId) {
      setEvents([]);
      return;
    }
    let cancelled = false;
    const fetchEvents = async () => {
      setEventsLoading(true);
      try {
        const data = await getTeamEvents(activeClubId, activeTeamId);
        if (!cancelled) setEvents(data || []);
      } catch {
        if (!cancelled) setEvents([]);
      } finally {
        if (!cancelled) setEventsLoading(false);
      }
    };
    fetchEvents();
    return () => { cancelled = true; };
  }, [activeClubId, activeTeamId]);

  // Fetch announcements
  useEffect(() => {
    if (!activeClubId || !activeTeamId) { setAnnouncements([]); return; }
    getTeamAnnouncements(activeClubId, activeTeamId).then(d => setAnnouncements(d || [])).catch(() => setAnnouncements([]));
  }, [activeClubId, activeTeamId]);

  // Get upcoming events
  const now = new Date();
  const upcoming = events
    .filter((e) => new Date(e.startAt) >= now)
    .sort((a, b) => new Date(a.startAt) - new Date(b.startAt))
    .slice(0, 4);
  const hasClubOrTeam = clubs.length > 0 || teams.length > 0;
  const roleless = !currentUser?.roles?.length;
  const canCreateClub = access.isManager || roleless;
  const canCreateTeam = access.isManager && clubs.length > 0;
  const showJoinTeam = !access.isManager;
  const homeSubtitle = access.isPlayer
    ? 'Open your team hub, schedule, and personal dashboard'
    : access.isManager
      ? 'Manage your clubs and teams from one place'
      : access.isAnalyst
        ? 'Jump into match history, stat entry, and player leaderboards'
        : access.isFitnessCoach
          ? 'Open fitness records and player physical profiles'
          : access.isDoctor
            ? 'Open medical records, clearance, and document requests'
            : access.isCoach
              ? 'Review your team, schedule, plans, and player profiles'
              : 'Open your team workspace';

  if (clubLoading) {
    return (
      <PageTransition className="flex-1">
        <TopBar title="Home" />
        <div className="flex items-center justify-center py-20"><LoadingSpinner /></div>
      </PageTransition>
    );
  }

  return (
    <PageTransition className="flex-1">
      <TopBar title="Home" />

      <div className="px-4 md:px-6 lg:px-8 pb-24 lg:pb-8 max-w-7xl mx-auto w-full">
        {hasClubOrTeam && (
          <div className="mb-5">
            <p className={`text-sm md:text-base ${isDark ? 'text-white/50' : 'text-gray-500'}`}>{homeSubtitle}</p>
          </div>
        )}

        {/* No clubs — prompt user to create one */}
        {!hasClubOrTeam && (
          <div className="mt-8">
            <EmptyState
              icon={Building2}
              title="No clubs yet"
              subtitle="Create your first club to get started, or wait for an invitation"
            />
            <div className="mt-4 flex flex-col sm:flex-row items-center justify-center gap-3">
              {canCreateClub && (
                <button
                  onClick={() => navigate('/app/add-club')}
                  className="px-6 py-3 rounded-card bg-primary text-white font-semibold hover:bg-primary-dark transition-colors"
                  id="btn-create-first-club"
                >
                  Create Club
                </button>
              )}
              {showJoinTeam && (
                <button
                  onClick={() => navigate('/app/join-team')}
                  className="px-6 py-3 rounded-card border-2 border-primary text-primary font-semibold hover:bg-primary/10 transition-colors"
                  id="btn-join-team"
                >
                  Join Team
                </button>
              )}
            </div>
          </div>
        )}

        {/* Team Cards Grid */}
        {teams.length > 0 && (
          <motion.div
            variants={staggerContainer}
            initial="initial"
            animate="animate"
            className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-3 md:gap-4 lg:gap-5"
          >
            {teams.map((team) => (
              <motion.div key={team.teamId} variants={staggerItem}>
                <TeamCard
                  team={team}
                  selected={team.teamId === activeTeamId}
                  onClick={() => {
                    selectTeam(team.teamId);
                    navigate('/app/team');
                  }}
                />
              </motion.div>
            ))}
          </motion.div>
        )}

        {/* No teams but has club */}
        {clubs.length > 0 && teams.length === 0 && (
          <div className="mt-8">
            <EmptyState
              icon={Building2}
              title="No teams yet"
              subtitle={canCreateTeam ? 'Create a team inside your club to get started' : 'Ask a manager to invite you to a team'}
            />
            <div className="mt-4 flex flex-col sm:flex-row items-center justify-center gap-3">
              {canCreateTeam && (
                <button
                  onClick={() => navigate('/app/add-team')}
                  className="px-6 py-3 rounded-card bg-primary text-white font-semibold hover:bg-primary-dark transition-colors"
                  id="btn-create-team"
                >
                  Create Team
                </button>
              )}
              {!canCreateTeam && showJoinTeam && (
                <button
                  onClick={() => navigate('/app/join-team')}
                  className="px-6 py-3 rounded-card border-2 border-primary text-primary font-semibold hover:bg-primary/10 transition-colors"
                  id="btn-join-team-from-empty"
                >
                  Join Team
                </button>
              )}
            </div>
          </div>
        )}

        {/* Upcoming Events */}
        {eventsLoading && (
          <div className="flex justify-center py-8"><LoadingSpinner /></div>
        )}
        {!eventsLoading && upcoming.length > 0 && (
          <div className="mt-6 lg:mt-8">
            <h2 className={`font-display text-section md:text-xl uppercase mb-3 md:mb-4 ${isDark ? 'text-white' : 'text-black'}`}>
              UPCOMING
            </h2>
            <div className="flex gap-3 md:gap-4 overflow-x-auto lg:overflow-visible lg:flex-wrap pb-2 -mx-4 px-4 lg:mx-0 lg:px-0">
              {upcoming.map((event) => (
                <EventCard key={event.eventId} event={event} />
              ))}
            </div>
          </div>
        )}
        {!eventsLoading && upcoming.length === 0 && teams.length > 0 && (
          <div className="mt-6 lg:mt-8">
            <EmptyState icon={Calendar} title="No upcoming events" subtitle={access.canManageEvents ? 'Create a match or training session to get started' : 'Events will appear here once added'} />
            {access.canManageEvents && (
              <button
                onClick={() => navigate('/app/add-event')}
                className="mx-auto mt-4 block px-6 py-3 rounded-card bg-primary text-white font-semibold hover:bg-primary-dark transition-colors"
                id="btn-create-event"
              >
                Create Event
              </button>
            )}
          </div>
        )}

        {/* Announcements */}
        {announcements.length > 0 && (
          <div className="mt-6 lg:mt-8">
            <h2 className={`font-display text-section md:text-xl uppercase mb-3 md:mb-4 ${isDark ? 'text-white' : 'text-black'}`}>ANNOUNCEMENTS</h2>
            <div className="space-y-2">
              {announcements.slice(0, 5).map((a) => (
                <div key={a.announcementId} className={`p-3 rounded-card shadow-sm ${isDark ? 'bg-surface-dark' : 'bg-white'} ${a.priority === 'Urgent' ? 'border-l-4 border-red-500' : a.priority === 'Important' ? 'border-l-4 border-yellow-500' : ''}`}>
                  <div className="flex items-center gap-2">
                    <Megaphone size={14} className={a.priority === 'Urgent' ? 'text-red-500' : a.priority === 'Important' ? 'text-yellow-500' : isDark ? 'text-white/50' : 'text-gray-400'} />
                    <h3 className={`font-semibold text-sm ${isDark ? 'text-white' : 'text-black'}`}>{a.title}</h3>
                  </div>
                  <p className={`text-xs mt-1 ${isDark ? 'text-white/60' : 'text-gray-600'}`}>{a.content}</p>
                  <p className={`text-[10px] mt-1 ${isDark ? 'text-white/30' : 'text-gray-400'}`}>By {a.creatorName} · {new Date(a.createdAt).toLocaleDateString()}</p>
                </div>
              ))}
            </div>
          </div>
        )}
        {announcements.length === 0 && teams.length > 0 && (
          <div className="mt-6 lg:mt-8">
            <EmptyState
              icon={Megaphone}
              title="No announcements yet"
              subtitle={access.canManageAnnouncements ? 'Share an update with the team' : 'Team updates will appear here when posted'}
            />
            {access.canManageAnnouncements && (
              <button
                onClick={() => navigate('/app/add-announcement')}
                className="mx-auto mt-4 block px-6 py-3 rounded-card bg-primary text-white font-semibold hover:bg-primary-dark transition-colors"
                id="btn-create-announcement"
              >
                Create Announcement
              </button>
            )}
          </div>
        )}
      </div>
    </PageTransition>
  );
}
