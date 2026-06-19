import axios from 'axios';

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || 'http://localhost:5122',
  headers: { 'Content-Type': 'application/json' },
});

// JWT interceptor — attaches Bearer token from localStorage
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('equipex_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor — handle 401 with token refresh
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    // If 401 and we haven't already retried, try refreshing
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;
      const refreshToken = localStorage.getItem('equipex_refresh_token');

      if (refreshToken) {
        try {
          const { data } = await axios.post(
            `${api.defaults.baseURL}/auth/refresh`,
            { refreshToken },
            { headers: { 'Content-Type': 'application/json' } }
          );

          if (data.accessToken) {
            localStorage.setItem('equipex_token', data.accessToken);
            if (data.refreshToken) {
              localStorage.setItem('equipex_refresh_token', data.refreshToken);
            }
            originalRequest.headers.Authorization = `Bearer ${data.accessToken}`;
            return api(originalRequest);
          }
        } catch {
          // Refresh failed — clear and redirect
        }
      }

      localStorage.removeItem('equipex_token');
      localStorage.removeItem('equipex_refresh_token');
      localStorage.removeItem('equipex_user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default api;
