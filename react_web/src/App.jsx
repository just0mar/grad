import { lazy, Suspense } from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { AnimatePresence } from 'framer-motion';
import { AuthProvider } from './hooks/useAuth';
import useAuth from './hooks/useAuth';
import { ThemeProvider } from './hooks/useTheme';
import { ClubProvider } from './hooks/useClub';
import useClub from './hooks/useClub';
import LoadingSpinner from './components/LoadingSpinner';
import { getRoleAccess, getRoleLandingRoute, isRoleless } from './utils/roleAccess';

const SplashPage = lazy(() => import('./pages/SplashPage'));
const OnboardingPage = lazy(() => import('./pages/OnboardingPage'));
const LoginPage = lazy(() => import('./pages/LoginPage'));
const SignUpPage = lazy(() => import('./pages/SignUpPage'));
const CongratsPage = lazy(() => import('./pages/CongratsPage'));

const MainLayout = lazy(() => import('./pages/MainLayout'));
const HomePage = lazy(() => import('./pages/HomePage'));
const EventsPage = lazy(() => import('./pages/EventsPage'));
const TeamPage = lazy(() => import('./pages/TeamPage'));
const ProfilePage = lazy(() => import('./pages/ProfilePage'));
const MessagesPage = lazy(() => import('./pages/MessagesPage'));
const ChatPage = lazy(() => import('./pages/ChatPage'));

const AddClubPage = lazy(() => import('./pages/AddClubPage'));
const AddTeamPage = lazy(() => import('./pages/AddTeamPage'));
const AddEventPage = lazy(() => import('./pages/AddEventPage'));
const AddMembersPage = lazy(() => import('./pages/AddMembersPage'));
const AddAnnouncementPage = lazy(() => import('./pages/AddAnnouncementPage'));
const JoinTeamPage = lazy(() => import('./pages/JoinTeamPage'));
const SettingsPage = lazy(() => import('./pages/SettingsPage'));
const SearchPage = lazy(() => import('./pages/SearchPage'));
const NotificationsPage = lazy(() => import('./pages/NotificationsPage'));
const MemberDetailPage = lazy(() => import('./pages/MemberDetailPage'));
const TeamStatsPage = lazy(() => import('./pages/TeamStatsPage'));
const GameHistoryPage = lazy(() => import('./pages/GameHistoryPage'));
const PlansPage = lazy(() => import('./pages/PlansPage'));
const AskEquipoPage = lazy(() => import('./pages/AskEquipoPage'));

function AppLoading() {
  return <div className="min-h-screen flex items-center justify-center"><LoadingSpinner /></div>;
}

function RequireAuth({ children }) {
  const { currentUser, loading } = useAuth();
  if (loading) return <AppLoading />;
  if (!currentUser) return <Navigate to="/login" replace />;
  return children;
}

function RequireRole({ children, allow, fallback }) {
  const { currentUser, isAdmin, loading: authLoading } = useAuth();
  const { activeTeamId, activeClubId, loading: clubLoading } = useClub();

  if (authLoading || clubLoading) return <AppLoading />;
  if (!currentUser) return <Navigate to="/login" replace />;

  const access = getRoleAccess(currentUser, isAdmin);
  const context = {
    hasTeam: Boolean(activeTeamId),
    hasClub: Boolean(activeClubId),
    currentUser,
    isRoleless: isRoleless(currentUser),
  };

  const target = fallback || getRoleLandingRoute(access, context);
  if (!allow(access, context)) return <Navigate to={target} replace />;
  return children;
}

function RoleLanding() {
  const { currentUser, isAdmin, loading: authLoading } = useAuth();
  const { activeTeamId, activeClubId, loading: clubLoading } = useClub();

  if (authLoading || clubLoading) return <AppLoading />;
  if (!currentUser) return <Navigate to="/login" replace />;

  const access = getRoleAccess(currentUser, isAdmin);
  const target = getRoleLandingRoute(access, {
    hasTeam: Boolean(activeTeamId),
    hasClub: Boolean(activeClubId),
    currentUser,
    isRoleless: isRoleless(currentUser),
  });

  return <Navigate to={target} replace />;
}

function AppRoutes() {
  return (
    <AnimatePresence mode="wait">
      <Routes>
        {/* Public routes */}
        <Route path="/" element={<SplashPage />} />
        <Route path="/onboarding" element={<OnboardingPage />} />
        <Route path="/login" element={<LoginPage />} />
        <Route path="/signup" element={<SignUpPage />} />
        <Route path="/congrats" element={<CongratsPage />} />

        {/* Main app shell with nested routes */}
        <Route path="/app" element={<RequireAuth><MainLayout /></RequireAuth>}>
          <Route index element={<RoleLanding />} />
          <Route path="home" element={<HomePage />} />
          <Route path="events" element={<RequireRole allow={(access, ctx) => ctx.hasTeam}><EventsPage /></RequireRole>} />
          <Route path="team" element={<TeamPage />} />
          <Route path="profile" element={<ProfilePage />} />
          <Route path="messages" element={<MessagesPage />} />
          <Route path="messages/:id" element={<ChatPage />} />
          <Route path="add-club" element={<RequireRole allow={(access, ctx) => access.isManager || ctx.isRoleless}><AddClubPage /></RequireRole>} />
          <Route path="add-team" element={<RequireRole allow={(access, ctx) => access.isManager && ctx.hasClub}><AddTeamPage /></RequireRole>} />
          <Route path="add-event" element={<RequireRole allow={(access, ctx) => access.canManageEvents && ctx.hasTeam} fallback="/app/team"><AddEventPage /></RequireRole>} />
          <Route path="add-members" element={<RequireRole allow={(access, ctx) => access.canManageTeam && ctx.hasTeam} fallback="/app/team"><AddMembersPage /></RequireRole>} />
          <Route path="add-announcement" element={<RequireRole allow={(access, ctx) => access.canManageAnnouncements && ctx.hasTeam} fallback="/app/team"><AddAnnouncementPage /></RequireRole>} />
          <Route path="join-team" element={<JoinTeamPage />} />
          <Route path="settings" element={<SettingsPage />} />
          <Route path="search" element={<SearchPage />} />
          <Route path="notifications" element={<NotificationsPage />} />
          <Route path="members/:id" element={<MemberDetailPage />} />
          <Route path="team-stats" element={<RequireRole allow={(access, ctx) => access.canViewStats && ctx.hasTeam} fallback="/app/team"><TeamStatsPage /></RequireRole>} />
          <Route path="game-history" element={<RequireRole allow={(access, ctx) => access.canViewStats && ctx.hasTeam} fallback="/app/team-stats"><GameHistoryPage /></RequireRole>} />
          <Route path="plans" element={<RequireRole allow={(access, ctx) => access.canViewPlans && ctx.hasTeam} fallback="/app/team"><PlansPage /></RequireRole>} />
          <Route path="ask-equipo" element={<AskEquipoPage />} />
        </Route>

        {/* Fallback */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AnimatePresence>
  );
}

export default function App() {
  return (
    <ThemeProvider>
      <AuthProvider>
        <ClubProvider>
          <Suspense fallback={<div className="min-h-screen flex items-center justify-center"><LoadingSpinner /></div>}>
            <AppRoutes />
          </Suspense>
        </ClubProvider>
      </AuthProvider>
    </ThemeProvider>
  );
}
