import api from './api';

export const getTeamAnnouncements = async (clubId, teamId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/announcements`);
  return data;
};

export const createAnnouncement = async (clubId, teamId, request) => {
  const { data } = await api.post(`/clubs/${clubId}/teams/${teamId}/announcements`, request);
  return data;
};

export const deleteAnnouncement = async (clubId, teamId, announcementId) => {
  await api.delete(`/clubs/${clubId}/teams/${teamId}/announcements/${announcementId}`);
};
