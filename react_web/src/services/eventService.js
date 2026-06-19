import api from './api';

const normalizeSeason = (season) => {
  if (!season) return null;

  return {
    ...season,
    seasonId: season.seasonId ?? season.SeasonId,
    teamId: season.teamId ?? season.TeamId,
    teamName: season.teamName ?? season.TeamName,
    createdBy: season.createdBy ?? season.CreatedBy,
    label: season.label ?? season.Label,
    startDate: season.startDate ?? season.StartDate,
    endDate: season.endDate ?? season.EndDate,
    isCurrent: season.isCurrent ?? season.IsCurrent,
  };
};

// GET /seasons
export const getSeasons = async () => {
  const { data } = await api.get('/seasons');
  return data.map(normalizeSeason);
};

// GET /seasons/current
export const getCurrentSeason = async () => {
  const { data } = await api.get('/seasons/current');
  return normalizeSeason(data);
};

// GET /clubs/:clubId/teams/:teamId/seasons/current
export const getCurrentTeamSeason = async (clubId, teamId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/seasons/current`);
  return normalizeSeason(data);
};

// GET /clubs/:clubId/teams/:teamId/events
export const getTeamEvents = async (clubId, teamId, from, to) => {
  const params = {};
  if (from) params.from = from;
  if (to) params.to = to;
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/events`, { params });
  return data;
};

// GET /clubs/:clubId/teams/:teamId/events/:eventId
export const getEvent = async (clubId, teamId, eventId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/events/${eventId}`);
  return data;
};

// POST /clubs/:clubId/teams/:teamId/events
export const createEvent = async (clubId, teamId, eventData) => {
  const { data } = await api.post(`/clubs/${clubId}/teams/${teamId}/events`, eventData);
  return data;
};

// PUT /clubs/:clubId/teams/:teamId/events/:eventId
export const updateEvent = async (clubId, teamId, eventId, eventData) => {
  const { data } = await api.put(`/clubs/${clubId}/teams/${teamId}/events/${eventId}`, eventData);
  return data;
};

// DELETE /clubs/:clubId/teams/:teamId/events/:eventId
export const deleteEvent = async (clubId, teamId, eventId) => {
  const { data } = await api.delete(`/clubs/${clubId}/teams/${teamId}/events/${eventId}`);
  return data;
};
