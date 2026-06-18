import { useState, useEffect, useCallback, createContext, useContext, useMemo } from 'react';
import { getMyClubs } from '../services/clubService';
import { getMyTeams } from '../services/teamService';
import useAuth from './useAuth';

const ClubContext = createContext(null);

const storageKey = (userId, key) => `equipex_${key}_${userId}`;

export function ClubProvider({ children }) {
  const { currentUser } = useAuth();
  const userId = currentUser?.userId;
  const [clubs, setClubs] = useState([]);
  const [teams, setTeams] = useState([]);
  const [activeClubId, setActiveClubIdState] = useState(null);
  const [activeTeamId, setActiveTeamIdState] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const persistSelection = useCallback((clubId, teamId) => {
    if (!userId) return;
    if (clubId) localStorage.setItem(storageKey(userId, 'active_club'), clubId);
    else localStorage.removeItem(storageKey(userId, 'active_club'));

    if (teamId) localStorage.setItem(storageKey(userId, 'active_team'), teamId);
    else localStorage.removeItem(storageKey(userId, 'active_team'));
  }, [userId]);

  const applySelection = useCallback((teamData, clubData) => {
    const savedTeamId = userId ? localStorage.getItem(storageKey(userId, 'active_team')) : null;
    const savedClubId = userId ? localStorage.getItem(storageKey(userId, 'active_club')) : null;
    const selectedTeam = teamData.find((team) => team.teamId === savedTeamId) || teamData[0] || null;
    const fallbackClubId = savedClubId && clubData.some((club) => club.clubId === savedClubId)
      ? savedClubId
      : clubData[0]?.clubId || null;

    const nextTeamId = selectedTeam?.teamId || null;
    const nextClubId = selectedTeam?.clubId || fallbackClubId;

    setActiveTeamIdState(nextTeamId);
    setActiveClubIdState(nextClubId);
    persistSelection(nextClubId, nextTeamId);
  }, [persistSelection, userId]);

  const loadContext = useCallback(async () => {
    if (!currentUser) {
      setClubs([]);
      setTeams([]);
      setActiveClubIdState(null);
      setActiveTeamIdState(null);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const [clubData, teamData] = await Promise.all([getMyClubs(), getMyTeams()]);
      const nextClubs = clubData || [];
      const nextTeams = teamData || [];
      setClubs(nextClubs);
      setTeams(nextTeams);
      applySelection(nextTeams, nextClubs);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to load clubs and teams');
    } finally {
      setLoading(false);
    }
  }, [applySelection, currentUser]);

  useEffect(() => {
    loadContext();
  }, [loadContext]);

  const selectTeam = useCallback((teamId) => {
    const team = teams.find((item) => item.teamId === teamId);
    if (!team) return;
    setActiveTeamIdState(team.teamId);
    setActiveClubIdState(team.clubId || null);
    persistSelection(team.clubId || null, team.teamId);
  }, [persistSelection, teams]);

  const setActiveTeamId = useCallback((teamId) => {
    if (!teamId) {
      setActiveTeamIdState(null);
      persistSelection(activeClubId, null);
      return;
    }
    selectTeam(teamId);
  }, [activeClubId, persistSelection, selectTeam]);

  const setActiveClubId = useCallback((clubId) => {
    setActiveClubIdState(clubId || null);
    const teamForClub = teams.find((team) => team.clubId === clubId) || null;
    setActiveTeamIdState(teamForClub?.teamId || null);
    persistSelection(clubId || null, teamForClub?.teamId || null);
  }, [persistSelection, teams]);

  const refreshClubs = useCallback(async () => {
    if (!currentUser) return;
    try {
      const clubData = await getMyClubs();
      setClubs(clubData || []);
    } catch {
      // Silently fail
    }
  }, [currentUser]);

  const refreshTeams = useCallback(async () => {
    if (!currentUser) return;
    try {
      const teamData = await getMyTeams();
      const nextTeams = teamData || [];
      setTeams(nextTeams);

      const selectedTeamStillExists = nextTeams.some((team) => team.teamId === activeTeamId);
      if (!selectedTeamStillExists) {
        const nextTeam = nextTeams[0] || null;
        setActiveTeamIdState(nextTeam?.teamId || null);
        setActiveClubIdState(nextTeam?.clubId || activeClubId);
        persistSelection(nextTeam?.clubId || activeClubId, nextTeam?.teamId || null);
      }
    } catch {
      // Silently fail
    }
  }, [activeClubId, activeTeamId, currentUser, persistSelection]);

  const selectedTeam = useMemo(
    () => teams.find((team) => team.teamId === activeTeamId) || null,
    [activeTeamId, teams]
  );

  const selectedClub = useMemo(
    () => clubs.find((club) => club.clubId === activeClubId) || null,
    [activeClubId, clubs]
  );

  const value = useMemo(() => ({
    clubs,
    teams,
    selectedClub,
    selectedTeam,
    activeClubId,
    activeTeamId,
    setActiveClubId,
    setActiveTeamId,
    selectTeam,
    loading,
    error,
    refreshClubs,
    refreshTeams,
  }), [
    activeClubId,
    activeTeamId,
    clubs,
    error,
    loading,
    refreshClubs,
    refreshTeams,
    selectTeam,
    selectedClub,
    selectedTeam,
    setActiveClubId,
    setActiveTeamId,
    teams,
  ]);

  return (
    <ClubContext.Provider value={value}>
      {children}
    </ClubContext.Provider>
  );
}

export function useClub() {
  const context = useContext(ClubContext);
  if (!context) throw new Error('useClub must be used within ClubProvider');
  return context;
}

export default useClub;
