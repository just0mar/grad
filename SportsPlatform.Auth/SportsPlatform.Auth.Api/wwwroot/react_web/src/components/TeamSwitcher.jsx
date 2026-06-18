import { Users } from 'lucide-react';
import useClub from '../hooks/useClub';
import useTheme from '../hooks/useTheme';

export default function TeamSwitcher() {
  const { isDark } = useTheme();
  const { teams, activeTeamId, selectTeam, loading } = useClub();

  if (loading) {
    return (
      <div className={`hidden sm:flex items-center gap-2 h-10 px-3 rounded-card border text-sm ${isDark ? 'border-white/10 text-white/50 bg-white/5' : 'border-gray-200 text-gray-500 bg-white'}`}>
        <Users size={16} />
        <span>Teams</span>
      </div>
    );
  }

  if (!teams.length) {
    return (
      <div className={`hidden sm:flex items-center gap-2 h-10 px-3 rounded-card border text-sm ${isDark ? 'border-white/10 text-white/50 bg-white/5' : 'border-gray-200 text-gray-500 bg-white'}`}>
        <Users size={16} />
        <span>No team</span>
      </div>
    );
  }

  return (
    <label className={`flex items-center gap-2 h-10 px-2 rounded-card border min-w-0 max-w-[170px] sm:max-w-[220px] ${isDark ? 'border-white/10 bg-surface-dark text-white' : 'border-gray-200 bg-white text-black shadow-sm'}`}>
      <Users size={16} className="text-primary flex-shrink-0" />
      <select
        value={activeTeamId || ''}
        onChange={(event) => selectTeam(event.target.value)}
        className={`w-full min-w-0 bg-transparent text-sm font-semibold outline-none cursor-pointer ${isDark ? 'text-white' : 'text-black'}`}
        aria-label="Select active team"
        id="team-switcher"
      >
        {teams.map((team) => (
          <option key={team.teamId} value={team.teamId}>
            {team.clubName ? `${team.clubName} / ${team.teamName}` : team.teamName}
          </option>
        ))}
      </select>
    </label>
  );
}
