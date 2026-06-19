import api from './api';

export const getTeamPlans = async (clubId, teamId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/plans`);
  return data;
};

export const createPlan = async (clubId, teamId, request) => {
  const { data } = await api.post(`/clubs/${clubId}/teams/${teamId}/plans`, request);
  return data;
};

export const getPlan = async (clubId, teamId, planId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/plans/${planId}`);
  return data;
};

export const updatePlan = async (clubId, teamId, planId, request) => {
  const { data } = await api.put(`/clubs/${clubId}/teams/${teamId}/plans/${planId}`, request);
  return data;
};

export const deletePlan = async (clubId, teamId, planId) => {
  await api.delete(`/clubs/${clubId}/teams/${teamId}/plans/${planId}`);
};

export const getTeamLineups = async (clubId, teamId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/lineups`);
  return data;
};

export const createLineup = async (clubId, teamId, request) => {
  const { data } = await api.post(`/clubs/${clubId}/teams/${teamId}/lineups`, request);
  return data;
};

export const getLineup = async (clubId, teamId, lineupId) => {
  const { data } = await api.get(`/clubs/${clubId}/teams/${teamId}/lineups/${lineupId}`);
  return data;
};

export const updateLineup = async (clubId, teamId, lineupId, request) => {
  const { data } = await api.put(`/clubs/${clubId}/teams/${teamId}/lineups/${lineupId}`, request);
  return data;
};

export const deleteLineup = async (clubId, teamId, lineupId) => {
  await api.delete(`/clubs/${clubId}/teams/${teamId}/lineups/${lineupId}`);
};
