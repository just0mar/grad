const STAFF_FULL = ['ClubManager', 'TeamManager'];
const STAFF_READ_ALL = ['Coach', 'TeamAnalyst', 'FitnessCoach', 'TeamDoctor'];

export const hasRole = (user, role) => Boolean(user?.roles?.includes(role));

export const hasAnyRole = (user, roles) => roles.some((role) => hasRole(user, role));

export const isRoleless = (user) => !(user?.roles?.length);

export const getRoleAccess = (user, isAdmin = false) => {
  const isManager = isAdmin || hasAnyRole(user, STAFF_FULL);
  const isCoach = hasRole(user, 'Coach');
  const isAnalyst = hasRole(user, 'TeamAnalyst');
  const isFitnessCoach = hasRole(user, 'FitnessCoach');
  const isDoctor = hasRole(user, 'TeamDoctor');
  const isPlayer = hasRole(user, 'Player') && !isManager && !hasAnyRole(user, STAFF_READ_ALL);

  return {
    isAdmin,
    isManager,
    isCoach,
    isAnalyst,
    isFitnessCoach,
    isDoctor,
    isPlayer,
    canManageTeam: isManager,
    canManageAttendance: isManager,
    canManageEvents: isManager,
    canManageAnnouncements: isManager,
    canEnterStats: isManager || isAnalyst,
    canWriteFitness: isAdmin || isFitnessCoach,
    canWriteMedical: isAdmin || isDoctor,
    canViewAllPlayerProfiles: isManager || isCoach || isAnalyst || isFitnessCoach || isDoctor,
    canViewAllPlayerStats: isManager || isCoach || isAnalyst || isFitnessCoach || isDoctor,
    canViewMedical: isManager || isCoach || isFitnessCoach || isDoctor || isPlayer,
    canViewFitness: isManager || isCoach || isFitnessCoach || isDoctor || isPlayer,
    canViewPlans: isManager || isCoach,
    canViewStats: isManager || isAnalyst || isCoach || isFitnessCoach || isDoctor || isPlayer,
  };
};

export const roleLabel = (role) => ({
  ClubManager: 'Club Manager',
  TeamManager: 'Team Manager',
  Coach: 'Coach',
  FitnessCoach: 'Fitness Coach',
  TeamAnalyst: 'Analyst',
  TeamDoctor: 'Doctor',
  Player: 'Player',
  Admin: 'Admin',
}[role] || role);

export const getRoleLandingRoute = (access, context = {}) => {
  const hasTeam = Boolean(context.hasTeam);
  const hasClub = Boolean(context.hasClub);
  const roleless = Boolean(context.isRoleless);

  if (!hasTeam && !hasClub) {
    if (access.isManager || roleless) return '/app/home';
    return '/app/join-team';
  }

  if (!hasTeam && hasClub) {
    if (access.isManager) return '/app/home';
    return '/app/home';
  }

  if (access.isAnalyst) return '/app/team-stats';
  if (access.isCoach) return '/app/plans';
  if (access.isFitnessCoach) return '/app/team?focus=fitness';
  if (access.isDoctor) return '/app/team?focus=medical';
  return '/app/team';
};
