import { useNavigate, useLocation } from 'react-router-dom';
import { Search, Bell } from 'lucide-react';
import { ArrowLeft } from 'lucide-react';
import useTheme from '../hooks/useTheme';
import TeamSwitcher from './TeamSwitcher';

export default function TopBar({ title, showBack = false, onBack }) {
  const navigate = useNavigate();
  const location = useLocation();
  const { isDark } = useTheme();

  const canGoBack = showBack || (location.key !== 'default' && window.history.length > 1);

  const handleBack = () => {
    if (onBack) return onBack();
    navigate(-1);
  };

  return (
    <header className="sticky top-0 z-30 flex items-center justify-between gap-2 px-4 md:px-6 lg:px-8 py-3 md:py-4 bg-transparent max-w-7xl mx-auto w-full">
      <div className="flex items-center gap-2 md:gap-3 min-w-0">
        {canGoBack && (
          <button
            onClick={handleBack}
            className={`p-2 rounded-full transition-colors ${isDark ? 'text-white hover:bg-white/10' : 'text-black hover:bg-black/5'}`}
            aria-label="Go back"
            id="btn-back"
          >
            <ArrowLeft size={22} />
          </button>
        )}
        <h1
          className={`font-display text-xl md:text-2xl lg:text-3xl uppercase tracking-wider truncate ${isDark ? 'text-white' : 'text-black'}`}
        >
          {title}
        </h1>
      </div>
      <div className="flex items-center gap-1 md:gap-2 flex-shrink-0">
        <TeamSwitcher />
        <button
          onClick={() => navigate('/app/search')}
          className={`p-2 md:p-2.5 rounded-full transition-colors ${isDark ? 'text-white hover:bg-white/10' : 'text-black hover:bg-black/5'}`}
          aria-label="Search"
          id="btn-search"
        >
          <Search size={22} />
        </button>
        <button
          onClick={() => navigate('/app/notifications')}
          className={`p-2 md:p-2.5 rounded-full transition-colors relative ${isDark ? 'text-white hover:bg-white/10' : 'text-black hover:bg-black/5'}`}
          aria-label="Notifications"
          id="btn-notifications"
        >
          <Bell size={22} />
        </button>
      </div>
    </header>
  );
}
