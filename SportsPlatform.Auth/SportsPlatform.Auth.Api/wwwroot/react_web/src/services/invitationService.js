import api from './api';

// GET /invitations/:token — preview an invitation
export const getInvitation = async (token) => {
  const { data } = await api.get(`/invitations/${token}`);
  return data;
};

// POST /invitations/:token/accept — accept an invitation
export const acceptInvitation = async (token) => {
  const { data } = await api.post(`/invitations/${token}/accept`);
  return data;
};

// POST /clubs/:clubId/teams/:teamId/invitations — create team invitation
export const createTeamInvitation = async (clubId, teamId, inviteData) => {
  const { data } = await api.post(`/clubs/${clubId}/teams/${teamId}/invitations`, inviteData);
  return data;
};

// GET /clubs/:clubId/teams/:teamId/invitations — list team invitations
export const getTeamInvitations = async (clubId, teamId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/invitations`);
  return data;
};

// DELETE /clubs/:clubId/teams/:teamId/invitations/:invitationId — cancel team invitation
export const cancelTeamInvitation = async (clubId, teamId, invitationId) => {
  const { data } = await api.delete(`/clubs/${clubId}/teams/${teamId}/invitations/${invitationId}`);
  return data;
};
