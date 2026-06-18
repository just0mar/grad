import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, CheckCircle } from 'lucide-react';
import PageTransition from '../components/PageTransition';
import FormInput from '../components/FormInput';
import LoadingSpinner from '../components/LoadingSpinner';
import useTheme from '../hooks/useTheme';
import { getInvitation, acceptInvitation } from '../services/invitationService';

export default function JoinTeamPage() {
  const { isDark } = useTheme();
  const navigate = useNavigate();
  const [token, setToken] = useState('');
  const [invitation, setInvitation] = useState(null);
  const [loading, setLoading] = useState(false);
  const [accepting, setAccepting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const handlePreview = async () => {
    if (!token.trim()) { setError('Please enter an invitation token'); return; }
    setError(''); setInvitation(null);
    setLoading(true);
    try {
      const data = await getInvitation(token.trim());
      setInvitation(data);
    } catch (err) {
      setError(err.response?.data?.error || 'Invitation not found or expired');
    } finally {
      setLoading(false);
    }
  };

  const handleAccept = async () => {
    setError(''); setAccepting(true);
    try {
      await acceptInvitation(token.trim());
      setSuccess('Invitation accepted! You may need to log in again to see updated roles.');
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to accept invitation');
    } finally {
      setAccepting(false);
    }
  };

  return (
    <PageTransition className="flex-1">
      <div className={`min-h-screen ${isDark ? 'bg-surface-darkest' : 'bg-gradient-to-b from-primary to-white'} relative`}>
        <div className="absolute inset-0 bg-[url('/assets/background.png')] bg-cover bg-center opacity-15" />
        <div className="relative z-10 max-w-lg mx-auto px-6 pt-6 pb-8">
          <div className="flex items-center gap-2 mb-8">
            <button onClick={() => navigate(-1)} className={`p-2 rounded-full ${isDark ? 'text-white' : 'text-black'}`}><ArrowLeft size={22} /></button>
            <h1 className={`font-display text-title uppercase ${isDark ? 'text-white' : 'text-black'}`}>ACCEPT INVITATION</h1>
          </div>
          {error && <div className="mb-4 p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{error}</div>}
          {success && (
            <div className="mb-4 p-4 rounded-card bg-green-500/10 border border-green-500/30 text-green-500 text-center">
              <CheckCircle size={32} className="mx-auto mb-2" />
              <p className="font-semibold">{success}</p>
              <button onClick={() => { localStorage.removeItem('equipex_token'); navigate('/login', { replace: true }); }}
                className="mt-3 px-4 py-2 rounded-card bg-primary text-white text-sm font-semibold">Log In Again</button>
            </div>
          )}
          {!success && (
            <div className="flex flex-col gap-4">
              <FormInput label="Invitation Token" value={token} onChange={(e) => setToken(e.target.value)} id="input-invite-token" />
              <button onClick={handlePreview} disabled={loading}
                className="w-full py-3.5 rounded-card bg-primary text-white font-semibold hover:bg-primary-dark transition-colors disabled:opacity-60" id="btn-preview-invite">
                {loading ? 'Looking up...' : 'Preview Invitation'}
              </button>
              {invitation && (
                <div className={`rounded-2xl p-5 ${isDark ? 'bg-surface-dark' : 'bg-white shadow-sm'}`}>
                  <h3 className={`font-semibold mb-3 ${isDark ? 'text-white' : 'text-black'}`}>Invitation Details</h3>
                  <div className="space-y-2 text-sm">
                    <p><span className={isDark ? 'text-white/50' : 'text-gray-500'}>Club:</span> <span className={isDark ? 'text-white' : 'text-black'}>{invitation.clubName}</span></p>
                    {invitation.teamName && <p><span className={isDark ? 'text-white/50' : 'text-gray-500'}>Team:</span> <span className={isDark ? 'text-white' : 'text-black'}>{invitation.teamName}</span></p>}
                    <p><span className={isDark ? 'text-white/50' : 'text-gray-500'}>Role:</span> <span className="text-primary font-semibold">{invitation.role}</span></p>
                    <p><span className={isDark ? 'text-white/50' : 'text-gray-500'}>From:</span> <span className={isDark ? 'text-white' : 'text-black'}>{invitation.inviterName}</span></p>
                    <p><span className={isDark ? 'text-white/50' : 'text-gray-500'}>Status:</span> <span className={isDark ? 'text-white' : 'text-black'}>{invitation.status}</span></p>
                  </div>
                  {invitation.status === 'Pending' && (
                    <button onClick={handleAccept} disabled={accepting}
                      className="w-full mt-4 py-3 rounded-card bg-green-600 text-white font-semibold hover:bg-green-700 transition-colors disabled:opacity-60">
                      {accepting ? 'Accepting...' : 'Accept Invitation'}
                    </button>
                  )}
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </PageTransition>
  );
}
