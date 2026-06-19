import api from './api';

// POST /clubs/:clubId/teams/:teamId/events/:eventId/attendance
export const recordAttendance = async (clubId, teamId, eventId, request) => {
  const { data } = await api.post(`/clubs/${clubId}/teams/${teamId}/events/${eventId}/attendance`, request);
  return data;
};

// GET /clubs/:clubId/teams/:teamId/events/:eventId/attendance
export const getEventAttendance = async (clubId, teamId, eventId, instanceDate) => {
  const params = {};
  if (instanceDate) params.instanceDate = instanceDate;
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/events/${eventId}/attendance`, { params });
  return data;
};

// PUT /clubs/:clubId/teams/:teamId/events/:eventId/attendance/:playerUserId
export const updateAttendance = async (clubId, teamId, eventId, playerUserId, request) => {
  const { data } = await api.put(`/clubs/${clubId}/teams/${teamId}/events/${eventId}/attendance/${playerUserId}`, request);
  return data;
};

// GET /clubs/:clubId/teams/:teamId/events/:eventId/attendance/me
export const getMyAttendance = async (clubId, teamId, eventId, instanceDate) => {
  const params = {};
  if (instanceDate) params.instanceDate = instanceDate;
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/events/${eventId}/attendance/me`, { params });
  return data;
};
