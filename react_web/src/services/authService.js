import api from './api';

// POST /auth/login
export const login = async ({ email, password }) => {
  const { data } = await api.post('/auth/login', { email, password });
  return data;
};

// POST /auth/register
export const register = async ({ email, password, name, username, phoneNumber, dob }) => {
  const { data } = await api.post('/auth/register', {
    email,
    password,
    name,
    username: username || undefined,
    phoneNumber: phoneNumber || undefined,
    dob,
  });
  return data;
};

// POST /auth/complete-google-profile
export const completeGoogleProfile = async ({ name, dob }) => {
  const { data } = await api.post('/auth/complete-google-profile', { name, dob });
  return data;
};

// POST /auth/refresh
export const refreshToken = async (refreshTokenValue) => {
  const { data } = await api.post('/auth/refresh', { refreshToken: refreshTokenValue });
  return data;
};

// POST /auth/logout
export const logout = async (refreshTokenValue) => {
  const { data } = await api.post('/auth/logout', { refreshToken: refreshTokenValue });
  return data;
};
