import api from './api';

// POST /clubs/:clubId/teams/:teamId/players/:playerUserId/fitness
export const createFitnessRecord = async (clubId, teamId, playerUserId, request) => {
  const { data } = await api.post(`/clubs/${clubId}/teams/${teamId}/players/${playerUserId}/fitness`, request);
  return data;
};

// GET /clubs/:clubId/teams/:teamId/players/:playerUserId/fitness
export const getPlayerFitnessRecords = async (clubId, teamId, playerUserId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/players/${playerUserId}/fitness`);
  return data;
};

// GET /players/me/fitness
export const getMyFitnessRecords = async () => {
  const { data } = await api.get('/players/me/fitness');
  return data;
};
