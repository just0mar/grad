import { Outlet, useLocation, useNavigate } from 'react-router-dom';
import BottomNav from '../components/BottomNav';
import Sidebar from '../components/Sidebar';
import SpeedDial from '../components/SpeedDial';
import useAuth from '../hooks/useAuth';
import useTheme from '../hooks/useTheme';
import useClub from '../hooks/useClub';
import { Activity, BarChart3, CalendarPlus, ClipboardCheck, FileText, HeartPulse, Megaphone, MessageSquare, Settings, Upload, User, UserPlus } from 'lucide-react';

function BasketballIcon({ size = 24, ...props }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      {...props}
    >
      <circle cx="12" cy="12" r="9" />
      <path d="M4.6 7.1c4.4 1.2 8.1 5.1 9.1 12.7" />
      <path d="M19.4 16.9c-4.4-1.2-8.1-5.1-9.1-12.7" />
      <path d="M3 12h18" />
      <path d="M12 3c2.1 2.3 3.2 5.3 3.2 9S14.1 18.7 12 21" />
      <path d="M12 3C9.9 5.3 8.8 8.3 8.8 12S9.9 18.7 12 21" />
    </svg>
  );
}

function withUniversalActions(actions, navigate) {
  return [
    ...actions,
    { icon: MessageSquare, label: 'Messages', onClick: () => navigate('/app/messages') },
    { icon: Settings, label: 'Settings', onClick: () => navigate('/app/settings') },
  ];
}

function getRoleActions(roles, isAdmin, hasClub, hasTeam, navigate) {
  const actions = [];
  const roleSet = new Set(roles || []);

  const isManager = roleSet.has('ClubManager') || roleSet.has('TeamManager') || isAdmin;
  const isCoach = roleSet.has('Coach');
  const isAnalyst = roleSet.has('TeamAnalyst');
  const isFitnessCoach = roleSet.has('FitnessCoach');
  const isDoctor = roleSet.has('TeamDoctor');
  const isPlayerOnly = roleSet.has('Player') && !isManager && !isCoach && !isAnalyst && !isFitnessCoach && !isDoctor;

  if (!hasClub || !hasTeam) return [];

  if (isManager) {
    actions.push({ icon: CalendarPlus, label: 'Create Event', onClick: () => navigate('/app/team?action=create-event') });
    actions.push({ icon: Megaphone, label: 'Post Announcement', onClick: () => navigate('/app/add-announcement') });
    actions.push({ icon: UserPlus, label: 'Invite Member', onClick: () => navigate('/app/add-members') });
    actions.push({ icon: ClipboardCheck, label: 'Mark Attendance', onClick: () => navigate('/app/team?action=attendance') });
    return withUniversalActions(actions, navigate);
  }

  if (isCoach) {
    actions.push({ icon: FileText, label: 'Add a Coaching Plan', onClick: () => navigate('/app/plans?action=create-plan') });
    actions.push({ icon: ClipboardCheck, label: 'Add a Lineup', onClick: () => navigate('/app/plans?action=create-lineup') });
  }
  if (isAnalyst) {
    actions.push({ icon: BarChart3, label: 'Enter Match Stats', onClick: () => navigate('/app/team-stats?tab=Entry') });
    actions.push({ icon: Upload, label: 'Upload Stats File', onClick: () => navigate('/app/team-stats?tab=Upload') });
  }
  if (isFitnessCoach) actions.push({ icon: Activity, label: 'Log Fitness Record', onClick: () => navigate('/app/team?focus=fitness') });
  if (isDoctor) {
    actions.push({ icon: HeartPulse, label: 'Add Medical Record', onClick: () => navigate('/app/team?focus=medical') });
    actions.push({ icon: HeartPulse, label: 'Request Document', onClick: () => navigate('/app/team?focus=medical') });
  }
  if (isPlayerOnly) actions.push({ icon: User, label: 'View My Profile', onClick: () => navigate('/app/profile') });

  return withUniversalActions(actions, navigate);
}

export default function MainLayout() {
  const { currentUser, isAdmin } = useAuth();
  const { isDark } = useTheme();
  const { clubs, teams } = useClub();
  const navigate = useNavigate();
  const location = useLocation();

  const hideFab = /^\/app\/(settings|profile-completion|complete-profile|onboarding)/.test(location.pathname);
  const fabActions = hideFab ? [] : getRoleActions(currentUser?.roles, isAdmin, clubs.length > 0 || teams.length > 0, teams.length > 0, navigate);

  return (
    <div className={`min-h-screen flex ${isDark ? 'bg-surface-darkest' : 'bg-gradient-to-b from-primary/10 to-white'}`}>
      <Sidebar />
      <main className="flex-1 flex flex-col relative min-h-screen overflow-x-hidden">
        <div className="fixed inset-0 bg-[url('/assets/background.png')] bg-cover bg-center opacity-[0.05] pointer-events-none z-0" />
        <div className="relative z-10 flex-1 flex flex-col w-full">
          <Outlet />
        </div>
        {!hideFab && fabActions.length > 0 && <SpeedDial actions={fabActions} icon={BasketballIcon} />}
        <BottomNav />
      </main>
    </div>
  );
}
