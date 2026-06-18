import api from './api';

// POST /clubs/:clubId/teams/:teamId/players/:playerUserId/medical
export const createMedicalRecord = async (clubId, teamId, playerUserId, request) => {
  const { data } = await api.post(`/clubs/${clubId}/teams/${teamId}/players/${playerUserId}/medical`, request);
  return data;
};

// PUT /clubs/:clubId/teams/:teamId/medical/:recordId
export const updateMedicalRecord = async (clubId, teamId, recordId, request) => {
  const { data } = await api.put(`/clubs/${clubId}/teams/${teamId}/medical/${recordId}`, request);
  return data;
};

// GET /clubs/:clubId/teams/:teamId/players/:playerUserId/medical
export const getPlayerMedicalRecords = async (clubId, teamId, playerUserId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/players/${playerUserId}/medical`);
  return data;
};

// PATCH /clubs/:clubId/teams/:teamId/medical/:recordId/clearance
export const updateMedicalClearance = async (clubId, teamId, recordId, request) => {
  const { data } = await api.patch(`/clubs/${clubId}/teams/${teamId}/medical/${recordId}/clearance`, request);
  return data;
};

// POST /clubs/:clubId/teams/:teamId/medical/:recordId/document-requests
export const requestMedicalDocument = async (clubId, teamId, recordId, request) => {
  const { data } = await api.post(`/clubs/${clubId}/teams/${teamId}/medical/${recordId}/document-requests`, request);
  return data;
};

// POST /players/me/medical/document-requests/:requestId/upload
export const uploadMedicalDocument = async (requestId, file) => {
  const formData = new FormData();
  formData.append('file', file);
  const { data } = await api.post(`/players/me/medical/document-requests/${requestId}/upload`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return data;
};

// GET /medical/document-requests/:requestId/download
export const downloadMedicalDocument = async (requestId, fallbackName = 'medical-document') => {
  const response = await api.get(`/medical/document-requests/${requestId}/download`, {
    responseType: 'blob',
  });
  const url = window.URL.createObjectURL(response.data);
  const link = document.createElement('a');
  const disposition = response.headers['content-disposition'] || '';
  const match = disposition.match(/filename\*=UTF-8''([^;]+)|filename="?([^"]+)"?/i);
  link.href = url;
  link.download = decodeURIComponent(match?.[1] || match?.[2] || fallbackName);
  document.body.appendChild(link);
  link.click();
  link.remove();
  window.URL.revokeObjectURL(url);
};

// GET /players/me/medical
export const getMyMedicalRecords = async () => {
  const { data } = await api.get('/players/me/medical');
  return data;
};
