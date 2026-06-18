import api from './api';

// GET /players/me/profile
export const getMyProfile = async () => {
  const { data } = await api.get('/players/me/profile');
  return data;
};

// GET /clubs/:clubId/teams/:teamId/players
export const getTeamPlayers = async (clubId, teamId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/players`);
  return data;
};

// GET /clubs/:clubId/teams/:teamId/players/:playerUserId/profile
export const getPlayerProfile = async (clubId, teamId, playerUserId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/players/${playerUserId}/profile`);
  return data;
};

// POST /clubs/:clubId/teams/:teamId/players/:playerUserId/profile
export const upsertPlayerProfile = async (clubId, teamId, playerUserId, profileData) => {
  const { data } = await api.post(`/clubs/${clubId}/teams/${teamId}/players/${playerUserId}/profile`, profileData);
  return data;
};
