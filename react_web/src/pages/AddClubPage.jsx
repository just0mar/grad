import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { motion } from 'framer-motion';
import { pageVariants } from '../animations/variants';
import FormInput from '../components/FormInput';
import useTheme from '../hooks/useTheme';
import useClub from '../hooks/useClub';
import { createClub } from '../services/clubService';

export default function AddClubPage() {
  const { isDark } = useTheme();
  const navigate = useNavigate();
  const { refreshClubs } = useClub();
  const [clubName, setClubName] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async () => {
    setError('');
    if (!clubName.trim()) { setError('Please enter a club name'); return; }
    setIsLoading(true);
    try {
      await createClub({ name: clubName.trim() });
      await refreshClubs();
      navigate('/app/home', { replace: true });
    } catch (err) {
      setError(err.response?.data?.error || err.response?.data?.message || 'Failed to create club');
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
          <button onClick={() => navigate('/app/home')} className={`p-2 rounded-full ${isDark ? 'text-white' : 'text-black'}`}><ArrowLeft size={22} /></button>
          <h1 className={`font-display text-title uppercase ${isDark ? 'text-white' : 'text-black'}`}>CREATE CLUB</h1>
        </div>
        {error && <div className="mb-4 p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{error}</div>}
        <div className="flex flex-col gap-4">
          <FormInput label="Club Name *" value={clubName} onChange={(e) => setClubName(e.target.value)} id="input-club-name" />
          <p className={`text-sm ${isDark ? 'text-white/50' : 'text-gray-500'}`}>
            You can add teams to your club after creating it.
          </p>
          <button onClick={handleSubmit} disabled={isLoading}
            className="w-full py-3.5 rounded-card bg-primary text-white font-semibold mt-4 hover:bg-primary-dark transition-colors disabled:opacity-60" id="btn-create-club">
            {isLoading ? 'Creating...' : 'Create Club'}
          </button>
        </div>
      </div>
    </motion.div>
  );
}
