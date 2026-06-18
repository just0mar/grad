import api from './api';

// GET /teams/categories (AllowAnonymous)
export const getCategories = async () => {
  const { data } = await api.get('/teams/categories');
  return data;
};

// GET /clubs/:clubId/teams
export const getClubTeams = async (clubId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams`);
  return data;
};

// GET /teams/my
export const getMyTeams = async () => {
  const { data } = await api.get('/teams/my');
  return data;
};

// GET /clubs/:clubId/teams/:teamId
export const getTeam = async (clubId, teamId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}`);
  return data;
};

// POST /clubs/:clubId/teams
export const createTeam = async (clubId, { teamName, categoryId, seasonLabel, seasonStartDate, seasonEndDate }) => {
  const { data } = await api.post(`/clubs/${clubId}/teams`, {
    teamName,
    categoryId,
    seasonLabel,
    seasonStartDate,
    seasonEndDate,
  });
  return data;
};

// DELETE /clubs/:clubId/teams/:teamId
export const deleteTeam = async (clubId, teamId) => {
  const { data } = await api.delete(`/clubs/${clubId}/teams/${teamId}`);
  return data;
};

// GET /clubs/:clubId/teams/:teamId/members
export const getTeamMembers = async (clubId, teamId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/members`);
  return data;
};

// DELETE /clubs/:clubId/teams/:teamId/members/:userId
export const removeTeamMember = async (clubId, teamId, userId) => {
  const { data } = await api.delete(`/clubs/${clubId}/teams/${teamId}/members/${userId}`);
  return data;
};
