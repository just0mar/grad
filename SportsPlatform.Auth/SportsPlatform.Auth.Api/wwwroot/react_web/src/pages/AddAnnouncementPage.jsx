import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import TopBar from '../components/TopBar';
import PageTransition from '../components/PageTransition';
import FormInput from '../components/FormInput';
import SelectField from '../components/SelectField';
import useTheme from '../hooks/useTheme';
import useClub from '../hooks/useClub';
import { createAnnouncement } from '../services/announcementService';

const PRIORITIES = ['Normal', 'Important', 'Urgent'];

export default function AddAnnouncementPage() {
  const { isDark } = useTheme();
  const navigate = useNavigate();
  const { activeClubId, activeTeamId } = useClub();
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [priority, setPriority] = useState('Normal');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async () => {
    setError('');
    if (!title.trim() || !content.trim()) { setError('Please fill in title and content'); return; }
    if (!activeClubId || !activeTeamId) { setError('No team selected'); return; }
    setIsLoading(true);
    try {
      await createAnnouncement(activeClubId, activeTeamId, { title: title.trim(), content: content.trim(), priority });
      navigate('/app/home', { replace: true });
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to create announcement');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <PageTransition className="flex-1">
      <TopBar title="New Announcement" showBack />
      <div className="px-4 md:px-6 lg:px-8 pb-24 lg:pb-8 max-w-2xl mx-auto w-full">
        {error && <div className="mb-4 p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{error}</div>}
        <div className="flex flex-col gap-4 mt-4">
          <FormInput label="Title *" value={title} onChange={(e) => setTitle(e.target.value)} id="input-title" />
          <div>
            <label className={`block text-sm font-medium mb-1 ${isDark ? 'text-white/70' : 'text-gray-600'}`}>Content *</label>
            <textarea
              value={content}
              onChange={(e) => setContent(e.target.value)}
              rows={5}
              className={`w-full px-4 py-3 rounded-card border text-sm transition-colors resize-none ${isDark ? 'bg-surface-dark border-white/10 text-white placeholder:text-white/30' : 'bg-white border-gray-200 text-black placeholder:text-gray-400'}`}
              placeholder="Write your announcement..."
              id="input-content"
            />
          </div>
          <SelectField label="Priority" value={priority} onChange={setPriority}
            options={PRIORITIES} optionValues={PRIORITIES} id="select-priority" />
          <button onClick={handleSubmit} disabled={isLoading}
            className="w-full py-3.5 rounded-card bg-primary text-white font-semibold mt-2 hover:bg-primary-dark transition-colors disabled:opacity-60" id="btn-submit">
            {isLoading ? 'Posting...' : 'Post Announcement'}
          </button>
        </div>
      </div>
    </PageTransition>
  );
}
