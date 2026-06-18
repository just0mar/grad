import { useState, useEffect, useCallback, createContext, useContext } from 'react';
import { login as loginService, register as registerService, logout as logoutService } from '../services/authService';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [currentUser, setCurrentUser] = useState(null);
  const [loading, setLoading] = useState(true);

  // On mount, restore user from localStorage & handle Google OAuth redirect
  useEffect(() => {
    // Check for Google OAuth redirect params in URL
    const params = new URLSearchParams(window.location.search);
    const accessToken = params.get('accessToken');
    const refreshToken = params.get('refreshToken');
    const requiresProfileCompletion = params.get('requiresProfileCompletion') === 'true';
    const status = params.get('status');

    if (accessToken && status === '200') {
      localStorage.setItem('equipex_token', accessToken);
      if (refreshToken) localStorage.setItem('equipex_refresh_token', refreshToken);

      const user = {
        userId: params.get('userId'),
        email: params.get('email'),
        name: params.get('name'),
        requiresProfileCompletion,
      };
      localStorage.setItem('equipex_user', JSON.stringify(user));
      setCurrentUser(user);

      // Clean up URL params
      window.history.replaceState({}, document.title, window.location.pathname);
      setLoading(false);
      return;
    }

    // Otherwise restore from localStorage
    const stored = localStorage.getItem('equipex_user');
    if (stored) {
      try {
        setCurrentUser(JSON.parse(stored));
      } catch {
        localStorage.removeItem('equipex_user');
      }
    }
    setLoading(false);
  }, []);

  const login = useCallback(async (credentials) => {
    const result = await loginService(credentials);

    // Backend returns: { accessToken, refreshToken, user: { userId, email, name, roles, clubs, teams, isAdmin }, message }
    localStorage.setItem('equipex_token', result.accessToken);
    if (result.refreshToken) localStorage.setItem('equipex_refresh_token', result.refreshToken);

    const user = result.user;
    localStorage.setItem('equipex_user', JSON.stringify(user));
    setCurrentUser(user);
    return user;
  }, []);

  const signup = useCallback(async (userData) => {
    const result = await registerService(userData);

    localStorage.setItem('equipex_token', result.accessToken);
    if (result.refreshToken) localStorage.setItem('equipex_refresh_token', result.refreshToken);

    const user = result.user;
    localStorage.setItem('equipex_user', JSON.stringify(user));
    setCurrentUser(user);
    return user;
  }, []);

  const logout = useCallback(async () => {
    const refreshToken = localStorage.getItem('equipex_refresh_token');
    try {
      if (refreshToken) await logoutService(refreshToken);
    } catch {
      // Ignore logout errors
    }
    localStorage.removeItem('equipex_token');
    localStorage.removeItem('equipex_refresh_token');
    localStorage.removeItem('equipex_user');
    setCurrentUser(null);
  }, []);

  const updateUser = useCallback((updatedUser) => {
    localStorage.setItem('equipex_user', JSON.stringify(updatedUser));
    setCurrentUser(updatedUser);
  }, []);

  // Derive primary role from user's roles/clubs/teams
  const primaryRole = currentUser?.roles?.[0] || null;
  const isAdmin = currentUser?.isAdmin || false;

  return (
    <AuthContext.Provider value={{ currentUser, loading, login, signup, logout, updateUser, primaryRole, isAdmin }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within AuthProvider');
  return context;
}

export default useAuth;
