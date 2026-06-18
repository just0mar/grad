import api from './api';

// GET /clubs/my
export const getMyClubs = async () => {
  const { data } = await api.get('/clubs/my');
  return data;
};

// GET /clubs/:clubId
export const getClub = async (clubId) => {
  const { data } = await api.get(`/clubs/${clubId}`);
  return data;
};

// POST /clubs
export const createClub = async ({ name }) => {
  const { data } = await api.post('/clubs', { name });
  return data;
};

// DELETE /clubs/:clubId
export const deleteClub = async (clubId) => {
  const { data } = await api.delete(`/clubs/${clubId}`);
  return data;
};

// GET /clubs/:clubId/members
export const getClubMembers = async (clubId) => {
  const { data } = await api.get(`/clubs/${clubId}/members`);
  return data;
};

// DELETE /clubs/:clubId/members/:userId
export const removeClubMember = async (clubId, userId) => {
  const { data } = await api.delete(`/clubs/${clubId}/members/${userId}`);
  return data;
};

// POST /clubs/:clubId/invitations
export const createClubInvitation = async (clubId, inviteData) => {
  const { data } = await api.post(`/clubs/${clubId}/invitations`, inviteData);
  return data;
};

// GET /clubs/:clubId/invitations
export const getClubInvitations = async (clubId) => {
  const { data } = await api.get(`/clubs/${clubId}/invitations`);
  return data;
};

// DELETE /clubs/:clubId/invitations/:invitationId
export const cancelClubInvitation = async (clubId, invitationId) => {
  const { data } = await api.delete(`/clubs/${clubId}/invitations/${invitationId}`);
  return data;
};
