import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { motion } from 'framer-motion';
import { pageVariants } from '../animations/variants';
import FormInput from '../components/FormInput';
import SelectField from '../components/SelectField';
import useTheme from '../hooks/useTheme';
import useClub from '../hooks/useClub';
import { createEvent, getCurrentTeamSeason } from '../services/eventService';

const EVENT_TYPES = ['Match', 'Training', 'Meeting', 'Test'];

export default function AddEventPage() {
  const { isDark } = useTheme();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { activeClubId, activeTeamId } = useClub();
  const [season, setSeason] = useState(null);
  const [type, setType] = useState('');
  const [title, setTitle] = useState('');
  const [startAt, setStartAt] = useState('');
  const [endAt, setEndAt] = useState('');
  const [location, setLocation] = useState('');
  const [description, setDescription] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (!activeClubId || !activeTeamId) {
      setSeason(null);
      return;
    }

    getCurrentTeamSeason(activeClubId, activeTeamId)
      .then(setSeason)
      .catch(() => setSeason(null));
  }, [activeClubId, activeTeamId]);

  useEffect(() => {
    const prefilledStart = searchParams.get('startAt');
    if (prefilledStart && !startAt) {
      setStartAt(prefilledStart);
      const end = new Date(prefilledStart);
      end.setHours(end.getHours() + 1);
      setEndAt(`${end.getFullYear()}-${String(end.getMonth() + 1).padStart(2, '0')}-${String(end.getDate()).padStart(2, '0')}T${String(end.getHours()).padStart(2, '0')}:${String(end.getMinutes()).padStart(2, '0')}`);
    }
  }, [searchParams, startAt]);

  const handleSubmit = async () => {
    if (!type || !title || !startAt) { setError('Please fill in event type, title, and start time'); return; }
    if (!activeClubId || !activeTeamId) { setError('No active team. Please create or select a team first.'); return; }
    const seasonId = season?.seasonId;
    if (!seasonId) { setError('No active season found for the selected team. Create or switch to a team with an active season.'); return; }
    setError('');
    setIsLoading(true);
    try {
      await createEvent(activeClubId, activeTeamId, {
        seasonId,
        title, eventType: type,
        startAt: new Date(startAt).toISOString(),
        endAt: endAt ? new Date(endAt).toISOString() : undefined,
        location: location || undefined,
        description: description || undefined,
      });
      navigate(searchParams.get('returnTo') || '/app/team', { replace: true });
    } catch (err) {
      setError(err.response?.data?.error || err.response?.data?.message || 'Failed to create event');
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
          <h1 className={`font-display text-title uppercase ${isDark ? 'text-white' : 'text-black'}`}>ADD EVENT</h1>
        </div>
        {activeTeamId && !season && <div className="mb-4 p-3 rounded-card bg-yellow-500/10 border border-yellow-500/30 text-yellow-600 text-sm">No active season found for this team.</div>}
        {error && <div className="mb-4 p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{error}</div>}
        <div className="flex flex-col gap-4">
          <FormInput label="Title *" value={title} onChange={(e) => setTitle(e.target.value)} id="input-event-title" />
          <SelectField label="Event Type *" value={type} onChange={setType} options={EVENT_TYPES} id="select-event-type" />
          <FormInput label="Start *" type="datetime-local" value={startAt} onChange={(e) => setStartAt(e.target.value)} id="input-event-start" />
          <FormInput label="End" type="datetime-local" value={endAt} onChange={(e) => setEndAt(e.target.value)} id="input-event-end" />
          <FormInput label="Location" value={location} onChange={(e) => setLocation(e.target.value)} id="input-event-location" />
          <FormInput label="Description" value={description} onChange={(e) => setDescription(e.target.value)} id="input-event-desc" />
          <button onClick={handleSubmit} disabled={isLoading || !season}
            className="w-full py-3.5 rounded-card bg-primary text-white font-semibold mt-4 hover:bg-primary-dark transition-colors disabled:opacity-60" id="btn-add-event">
            {isLoading ? 'Creating...' : 'Create Event'}
          </button>
        </div>
      </div>
    </motion.div>
  );
}
