import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { motion } from 'framer-motion';
import { pageVariants } from '../animations/variants';
import FormInput from '../components/FormInput';
import SelectField from '../components/SelectField';
import useTheme from '../hooks/useTheme';
import useClub from '../hooks/useClub';
import { createTeam, getCategories } from '../services/teamService';

const getDefaultSeason = () => {
  const now = new Date();
  const startYear = now.getMonth() >= 6 ? now.getFullYear() : now.getFullYear() - 1;

  return {
    label: `${startYear}/${startYear + 1}`,
    startDate: `${startYear}-07-01`,
    endDate: `${startYear + 1}-06-30`,
  };
};

export default function AddTeamPage() {
  const { isDark } = useTheme();
  const navigate = useNavigate();
  const { clubs, activeClubId, refreshTeams } = useClub();
  const defaultSeason = getDefaultSeason();
  const [categories, setCategories] = useState([]);
  const [teamName, setTeamName] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [seasonLabel, setSeasonLabel] = useState(defaultSeason.label);
  const [seasonStartDate, setSeasonStartDate] = useState(defaultSeason.startDate);
  const [seasonEndDate, setSeasonEndDate] = useState(defaultSeason.endDate);
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    getCategories().then(setCategories).catch(() => {});
  }, []);

  // If user has no club, redirect to club creation
  useEffect(() => {
    if (clubs.length === 0) {
      navigate('/app/add-club', { replace: true });
    }
  }, [clubs, navigate]);

  const handleSubmit = async () => {
    setError('');
    if (!teamName.trim() || !categoryId) { setError('Please fill in team name and category'); return; }
    if (!seasonLabel.trim() || !seasonStartDate || !seasonEndDate) { setError('Please fill in season label, start date, and end date'); return; }
    if (new Date(seasonEndDate) <= new Date(seasonStartDate)) { setError('Season end date must be after the start date'); return; }
    if (!activeClubId) { setError('No club selected'); return; }
    setIsLoading(true);
    try {
      await createTeam(activeClubId, {
        teamName: teamName.trim(),
        categoryId,
        seasonLabel: seasonLabel.trim(),
        seasonStartDate,
        seasonEndDate,
      });
      await refreshTeams();
      navigate('/app/home', { replace: true });
    } catch (err) {
      setError(err.response?.data?.error || err.response?.data?.message || 'Failed to create team');
    } finally {
      setIsLoading(false);
    }
  };

  const categoryOptions = categories.map((c) => ({ label: `${c.name}${c.minAge ? ` (${c.minAge}-${c.maxAge})` : ''}`, value: c.categoryId }));

  return (
    <motion.div variants={pageVariants} initial="initial" animate="animate" exit="exit"
      className={`min-h-screen ${isDark ? 'bg-surface-darkest' : 'bg-gradient-to-b from-primary to-white'} relative`}>
      <div className="absolute inset-0 bg-[url('/assets/background.png')] bg-cover bg-center opacity-15" />
      <div className="relative z-10 max-w-lg mx-auto px-6 pt-6 pb-8">
        <div className="flex items-center gap-2 mb-8">
          <button onClick={() => navigate(-1)} className={`p-2 rounded-full ${isDark ? 'text-white' : 'text-black'}`}><ArrowLeft size={22} /></button>
          <h1 className={`font-display text-title uppercase ${isDark ? 'text-white' : 'text-black'}`}>ADD TEAM</h1>
        </div>
        {error && <div className="mb-4 p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{error}</div>}
        <div className="flex flex-col gap-4">
          <FormInput label="Team Name *" value={teamName} onChange={(e) => setTeamName(e.target.value)} id="input-team-name" />
          <SelectField label="Category *" value={categoryId} onChange={setCategoryId}
            options={categoryOptions.map((o) => o.label)} optionValues={categoryOptions.map((o) => o.value)} id="select-category" />
          <FormInput label="Season Label *" value={seasonLabel} onChange={(e) => setSeasonLabel(e.target.value)} id="input-season-label" />
          <FormInput label="Season Start *" type="date" value={seasonStartDate} onChange={(e) => setSeasonStartDate(e.target.value)} id="input-season-start" />
          <FormInput label="Season End *" type="date" value={seasonEndDate} onChange={(e) => setSeasonEndDate(e.target.value)} id="input-season-end" />
          <button onClick={handleSubmit} disabled={isLoading}
            className="w-full py-3.5 rounded-card bg-primary text-white font-semibold mt-4 hover:bg-primary-dark transition-colors disabled:opacity-60" id="btn-add-team">
            {isLoading ? 'Creating...' : 'Create Team'}
          </button>
        </div>
      </div>
    </motion.div>
  );
}
