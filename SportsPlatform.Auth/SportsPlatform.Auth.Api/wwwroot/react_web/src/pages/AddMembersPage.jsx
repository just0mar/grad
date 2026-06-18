import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { motion } from 'framer-motion';
import { pageVariants } from '../animations/variants';
import FormInput from '../components/FormInput';
import SelectField from '../components/SelectField';
import useTheme from '../hooks/useTheme';
import useClub from '../hooks/useClub';
import useAuth from '../hooks/useAuth';
import { createClubInvitation } from '../services/clubService';
import { createTeamInvitation } from '../services/invitationService';
import { getRoleAccess } from '../utils/roleAccess';

const CLUB_ROLES = ['TeamManager'];
const TEAM_ROLES = ['TeamManager', 'Coach', 'FitnessCoach', 'TeamAnalyst', 'TeamDoctor', 'Player'];
const ROLE_DISPLAY = {
  TeamManager: 'Team Manager', Coach: 'Coach', FitnessCoach: 'Fitness Coach',
  TeamAnalyst: 'Analyst', TeamDoctor: 'Doctor', Player: 'Player',
};

export default function AddMembersPage() {
  const { isDark } = useTheme();
  const navigate = useNavigate();
  const { activeClubId, activeTeamId } = useClub();
  const { currentUser, isAdmin } = useAuth();
  const access = getRoleAccess(currentUser, isAdmin);
  const [email, setEmail] = useState('');
  const [roleName, setRoleName] = useState('');
  const [playerPosition, setPlayerPosition] = useState('');
  const [jerseyNumber, setJerseyNumber] = useState('');
  const [inviteType, setInviteType] = useState('team');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const isPlayerRole = roleName === 'Player';
  const availableRoles = inviteType === 'club' ? CLUB_ROLES : TEAM_ROLES;
  const canInviteAtClubLevel = isAdmin || currentUser?.roles?.includes('ClubManager');

  const handleSubmit = async () => {
    if (!email || !roleName) { setError('Please fill in email and role'); return; }
    if (!access.canManageTeam) { setError('You do not have permission to invite members for this team.'); return; }
    if (inviteType === 'club' && !canInviteAtClubLevel) { setError('Only a club manager can send club-level invitations.'); return; }
    if (!activeClubId || (inviteType === 'team' && !activeTeamId)) { setError('Select a team before sending an invitation.'); return; }
    if (isPlayerRole && (!playerPosition || !jerseyNumber)) { setError('Position and jersey number are required for players'); return; }
    setError(''); setSuccess('');
    setIsLoading(true);
    try {
      const payload = { email, roleName, playerPosition: isPlayerRole ? playerPosition : undefined, jerseyNumber: isPlayerRole ? parseInt(jerseyNumber) : undefined };
      if (inviteType === 'club') {
        await createClubInvitation(activeClubId, payload);
      } else {
        await createTeamInvitation(activeClubId, activeTeamId, payload);
      }
      setSuccess('Invitation sent successfully!');
      setEmail(''); setRoleName(''); setPlayerPosition(''); setJerseyNumber('');
    } catch (err) {
      setError(err.response?.data?.error || err.response?.data?.message || 'Failed to send invitation');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <motion.div variants={pageVariants} initial="initial" animate="animate" exit="exit"
      className={`min-h-screen ${isDark ? 'bg-surface-darkest' : 'bg-gradient-to-b from-primary to-white'} relative`}>
      <div className="absolute inset-0 bg-[url('/assets/background.png')] bg-cover bg-center opacity-15" />
      <div className="relative z-10 max-w-lg mx-auto px-6 pt-6 pb-8">
        <div className="flex items-center gap-2 mb-8">
          <button onClick={() => navigate('/app/team')} className={`p-2 rounded-full ${isDark ? 'text-white' : 'text-black'}`}><ArrowLeft size={22} /></button>
          <h1 className={`font-display text-title uppercase ${isDark ? 'text-white' : 'text-black'}`}>INVITE MEMBER</h1>
        </div>
        {error && <div className="mb-4 p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{error}</div>}
        {success && <div className="mb-4 p-3 rounded-card bg-green-500/10 border border-green-500/30 text-green-500 text-sm">{success}</div>}
        <div className="flex flex-col gap-4">
          <div className="flex gap-2">
            {['team', ...(canInviteAtClubLevel ? ['club'] : [])].map((t) => (
              <button key={t} onClick={() => { setInviteType(t); setRoleName(''); }}
                className={`flex-1 py-2 rounded-pill text-sm font-medium transition-all ${inviteType === t ? 'bg-primary text-white' : isDark ? 'bg-surface-dark text-white/70' : 'bg-gray-100 text-gray-600'}`}>
                {t === 'team' ? 'Team Invitation' : 'Club Invitation'}
              </button>
            ))}
          </div>
          <FormInput label="Email *" type="email" value={email} onChange={(e) => setEmail(e.target.value)} id="input-invite-email" />
          <SelectField label="Role *" value={roleName} onChange={setRoleName}
            options={availableRoles.map((r) => ROLE_DISPLAY[r] || r)} optionValues={availableRoles} id="select-invite-role" />
          {isPlayerRole && (
            <>
              <FormInput label="Position *" value={playerPosition} onChange={(e) => setPlayerPosition(e.target.value)} id="input-player-position" />
              <FormInput label="Jersey Number *" type="number" value={jerseyNumber} onChange={(e) => setJerseyNumber(e.target.value)} id="input-jersey-number" />
            </>
          )}
          <button onClick={handleSubmit} disabled={isLoading}
            className="w-full py-3.5 rounded-card bg-primary text-white font-semibold mt-4 hover:bg-primary-dark transition-colors disabled:opacity-60" id="btn-send-invite">
            {isLoading ? 'Sending...' : 'Send Invitation'}
          </button>
        </div>
      </div>
    </motion.div>
  );
}
