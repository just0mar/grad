import api from './api';

export const getTeamStats = async (clubId, teamId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/stats`);
  return data;
};

export const createStats = async (clubId, teamId, request) => {
  const { data } = await api.post(`/clubs/${clubId}/teams/${teamId}/stats`, request);
  return data;
};

export const uploadStatsFile = async (clubId, teamId, eventId, file) => {
  const formData = new FormData();
  formData.append('eventId', eventId);
  formData.append('file', file);
  const { data } = await api.post(`/clubs/${clubId}/teams/${teamId}/stats/upload`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return data;
};

export const getMatchHistory = async (clubId, teamId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/stats/matches`);
  return data;
};

export const getMatchStats = async (clubId, teamId, eventId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/stats/matches/${eventId}`);
  return data;
};

export const getPlayerStats = async (clubId, teamId, playerUserId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/stats/players/${playerUserId}`);
  return data;
};

export const getPlayerMatchHistory = async (clubId, teamId, playerUserId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/stats/players/${playerUserId}/matches`);
  return data;
};

export const recordStats = createStats;
