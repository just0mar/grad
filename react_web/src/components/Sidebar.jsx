import { useEffect, useMemo, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { BarChart3, Building2, Calendar, ChevronLeft, ChevronRight, FileText, Home, LogOut, MessageSquare, Moon, Settings, Sun, User, UserPlus, Users } from 'lucide-react';
import useTheme from '../hooks/useTheme';
import useAuth from '../hooks/useAuth';
import useClub from '../hooks/useClub';
import { getRoleAccess, isRoleless } from '../utils/roleAccess';

const TEAM_MATCHES = ['/app/team', '/app/events', '/app/team-stats', '/app/game-history', '/app/plans', '/app/add-event', '/app/add-members', '/app/add-announcement', '/app/members'];
const STATS_MATCHES = ['/app/team-stats', '/app/game-history'];

export default function Sidebar() {
  const location = useLocation();
  const navigate = useNavigate();
  const { isDark, toggleTheme } = useTheme();
  const { currentUser, isAdmin, logout } = useAuth();
  const { activeTeamId, clubs } = useClub();
  const [minimized, setMinimized] = useState(() => localStorage.getItem('sidebar-minimized') === 'true');

  const access = getRoleAccess(currentUser, isAdmin);
  const hasTeam = Boolean(activeTeamId);
  const hasClub = clubs.length > 0;
  const roleless = isRoleless(currentUser);

  const navItems = useMemo(() => [
    { icon: Home, label: 'Home', path: '/app/home', match: ['/app/home'] },
    { icon: Users, label: 'Team Hub', path: '/app/team', match: TEAM_MATCHES, hidden: !hasTeam },
    { icon: Calendar, label: 'Events', path: '/app/events', match: ['/app/events'], hidden: !hasTeam },
    { icon: BarChart3, label: 'Stats', path: '/app/team-stats', match: STATS_MATCHES, hidden: !hasTeam || !access.canViewStats },
    { icon: FileText, label: 'Plans', path: '/app/plans', match: ['/app/plans'], hidden: !hasTeam || !access.canViewPlans },
    { icon: UserPlus, label: 'Join Team', path: '/app/join-team', match: ['/app/join-team'], hidden: hasTeam || access.isManager },
    { icon: Building2, label: 'Create Club', path: '/app/add-club', match: ['/app/add-club'], hidden: !(access.isManager || roleless) || hasClub },
    { icon: Users, label: 'Add Team', path: '/app/add-team', match: ['/app/add-team'], hidden: !access.isManager || !hasClub },
    { icon: MessageSquare, label: 'Messages', path: '/app/messages', match: ['/app/messages'] },
    { icon: User, label: 'My Profile', path: '/app/profile', match: ['/app/profile'] },
    { icon: Settings, label: 'Settings', path: '/app/settings', match: ['/app/settings'] },
  ], [access.canViewPlans, access.canViewStats, access.isManager, hasClub, hasTeam, roleless]);

  useEffect(() => {
    localStorage.setItem('sidebar-minimized', String(minimized));
  }, [minimized]);

  const handleLogout = async () => {
    await logout();
    navigate('/login', { replace: true });
  };

  return (
    <aside
      className={`hidden lg:flex flex-col h-screen sticky top-0 p-4 border-r transition-all duration-300 ease-out ${
        minimized ? 'w-20' : 'w-64'
      } ${
        isDark ? 'bg-surface-dark border-white/10' : 'bg-white border-gray-200'
      }`}
      id="sidebar"
    >
      <div className={`flex items-center mb-6 ${minimized ? 'justify-center' : 'justify-between gap-2'}`}>
        <button
          onClick={() => navigate('/app/home')}
          className={`flex items-center gap-3 py-4 text-left overflow-hidden ${minimized ? 'px-0 justify-center' : 'px-3'}`}
          title="Equipex"
        >
          <img src="/assets/logo.png" alt="Equipex" className={`${minimized ? 'w-12 h-12' : 'w-16 h-16'} object-contain shrink-0 transition-all duration-300`} />
          <h2
            className={`font-display text-xl uppercase tracking-wider text-primary whitespace-nowrap transition-all duration-300 ${
              minimized ? 'w-0 opacity-0' : 'w-auto opacity-100'
            }`}
          >
            Equipex
          </h2>
        </button>
        <button
          onClick={() => setMinimized((prev) => !prev)}
          className={`w-9 h-9 rounded-card flex items-center justify-center transition-all duration-200 ${
            isDark ? 'text-white/70 hover:bg-white/10 hover:text-white' : 'text-gray-600 hover:bg-gray-100 hover:text-black'
          } ${minimized ? 'absolute top-8 -right-4 shadow-md bg-primary text-white hover:bg-primary-dark hover:text-white' : ''}`}
          id="sidebar-toggle"
          aria-label={minimized ? 'Expand sidebar' : 'Minimize sidebar'}
          title={minimized ? 'Expand sidebar' : 'Minimize sidebar'}
        >
          {minimized ? <ChevronRight size={18} /> : <ChevronLeft size={18} />}
        </button>
      </div>

      <nav className="flex-1 flex flex-col gap-1">
        {navItems.filter((item) => !item.hidden).map(({ icon: Icon, label, path, match }) => {
          const matchers = match || [path];
          const isActive = matchers.some((matcher) => location.pathname === matcher || location.pathname.startsWith(matcher + '/'));
          return (
            <button
              key={path}
              onClick={() => navigate(path)}
              className={`flex items-center gap-3 px-4 py-3 rounded-card text-sm font-medium transition-all duration-200 ${
                minimized ? 'justify-center' : ''
              } ${
                isActive
                  ? 'bg-primary text-white shadow-md'
                  : isDark
                    ? 'text-white/70 hover:bg-white/10 hover:text-white'
                    : 'text-gray-600 hover:bg-gray-100 hover:text-black'
              }`}
              id={`sidebar-${label.toLowerCase().replace(/\s+/g, '-')}`}
              title={label}
            >
              <Icon size={20} className="shrink-0" />
              <span
                className={`whitespace-nowrap transition-all duration-300 ${
                  minimized ? 'w-0 opacity-0 overflow-hidden' : 'w-auto opacity-100'
                }`}
              >
                {label}
              </span>
            </button>
          );
        })}
      </nav>

      <button
        onClick={toggleTheme}
        className={`flex items-center gap-3 px-4 py-3 rounded-card text-sm font-medium transition-all duration-200 mt-4 ${
          minimized ? 'justify-center' : ''
        } ${
          isDark ? 'text-white/70 hover:bg-white/10 hover:text-white' : 'text-gray-600 hover:bg-gray-100 hover:text-black'
        }`}
        id="btn-theme-toggle"
        title={isDark ? 'Light Mode' : 'Dark Mode'}
      >
        {isDark ? <Sun size={20} className="shrink-0" /> : <Moon size={20} className="shrink-0" />}
        <span
          className={`whitespace-nowrap transition-all duration-300 ${
            minimized ? 'w-0 opacity-0 overflow-hidden' : 'w-auto opacity-100'
          }`}
        >
          {isDark ? 'Light Mode' : 'Dark Mode'}
        </span>
      </button>

      <button
        onClick={handleLogout}
        className={`flex items-center gap-3 px-4 py-3 rounded-card text-sm font-medium text-red-500 hover:bg-red-500/10 transition-all duration-200 mt-4 ${
          minimized ? 'justify-center' : ''
        }`}
        id="sidebar-logout"
        title="Logout"
      >
        <LogOut size={20} className="shrink-0" />
        <span
          className={`whitespace-nowrap transition-all duration-300 ${
            minimized ? 'w-0 opacity-0 overflow-hidden' : 'w-auto opacity-100'
          }`}
        >
          Logout
        </span>
      </button>
    </aside>
  );
}
