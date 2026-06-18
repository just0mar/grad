import { useLocation, useNavigate } from 'react-router-dom';
import { BarChart3, Calendar, FileText, Home, MessageSquare, Settings, User, UserPlus, Users } from 'lucide-react';
import useTheme from '../hooks/useTheme';
import useClub from '../hooks/useClub';
import useAuth from '../hooks/useAuth';
import { getRoleAccess } from '../utils/roleAccess';

const TEAM_MATCHES = ['/app/team', '/app/events', '/app/team-stats', '/app/game-history', '/app/plans', '/app/add-event', '/app/add-members', '/app/add-announcement', '/app/members'];
const STATS_MATCHES = ['/app/team-stats', '/app/game-history'];

export default function BottomNav() {
  const location = useLocation();
  const navigate = useNavigate();
  const { isDark } = useTheme();
  const { activeTeamId, clubs } = useClub();
  const { currentUser, isAdmin } = useAuth();

  const access = getRoleAccess(currentUser, isAdmin);
  const hasTeam = Boolean(activeTeamId);
  const hasClub = clubs.length > 0;

  const teamItem = hasTeam
    ? { icon: Users, label: 'Team', path: '/app/team', match: TEAM_MATCHES }
    : (access.isManager && hasClub
      ? { icon: Users, label: 'Add Team', path: '/app/add-team', match: ['/app/add-team'] }
      : (!access.isManager
        ? { icon: UserPlus, label: 'Join', path: '/app/join-team', match: ['/app/join-team'] }
        : null));

  const roleItem = hasTeam
    ? (access.isAnalyst
      ? { icon: BarChart3, label: 'Stats', path: '/app/team-stats', match: STATS_MATCHES }
      : access.isCoach
        ? { icon: FileText, label: 'Plans', path: '/app/plans', match: ['/app/plans'] }
        : access.isManager
          ? { icon: Calendar, label: 'Events', path: '/app/events', match: ['/app/events'] }
          : access.isPlayer
            ? { icon: BarChart3, label: 'Stats', path: '/app/team-stats', match: STATS_MATCHES }
            : null)
    : null;

  const navItems = [
    { icon: Home, label: 'Home', path: '/app/home', match: ['/app/home'] },
    teamItem,
    roleItem,
    { icon: MessageSquare, label: 'Messages', path: '/app/messages', match: ['/app/messages'] },
    { icon: User, label: 'Profile', path: '/app/profile', match: ['/app/profile'] },
    (!roleItem ? { icon: Settings, label: 'Settings', path: '/app/settings', match: ['/app/settings'] } : null),
  ].filter(Boolean).slice(0, 5);

  return (
    <nav
      className={`lg:hidden fixed bottom-0 left-0 right-0 z-40 flex items-center justify-around h-nav border-t ${
        isDark
          ? 'bg-surface-dark border-white/10'
          : 'bg-white border-gray-200 shadow-[0_-2px_8px_rgba(0,0,0,0.1)]'
      }`}
      id="bottom-nav"
    >
      {navItems.map(({ icon: Icon, label, path, match }) => {
        const matchers = match || [path];
        const isActive = matchers.some((matcher) => location.pathname === matcher || location.pathname.startsWith(matcher + '/'));

        return (
          <button
            key={path}
            onClick={() => navigate(path)}
            className="flex flex-col items-center justify-center h-full flex-1 touch-target"
            aria-label={label}
            id={`nav-${label.toLowerCase()}`}
          >
            {isActive ? (
              <div className="w-10 h-10 flex items-center justify-center rounded-full bg-primary transition-all duration-200">
                <Icon size={20} className="text-white" />
              </div>
            ) : (
              <>
                <Icon
                  size={20}
                  className={isDark ? 'text-white/60' : 'text-gray-500'}
                />
                <span
                  className={`text-nav mt-1 ${isDark ? 'text-white' : 'text-black'} font-bold`}
                >
                  {label}
                </span>
              </>
            )}
          </button>
        );
      })}
    </nav>
  );
}
