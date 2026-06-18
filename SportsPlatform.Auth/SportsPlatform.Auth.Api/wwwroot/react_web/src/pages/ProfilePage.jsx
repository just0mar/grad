import { useEffect, useState } from 'react';
import { Moon, Sun, LogOut, ChevronRight, Building2, FileText, Upload, Heart, Download } from 'lucide-react';
import TopBar from '../components/TopBar';
import PageTransition from '../components/PageTransition';
import Avatar from '../components/Avatar';
import useTheme from '../hooks/useTheme';
import useAuth from '../hooks/useAuth';
import useClub from '../hooks/useClub';
import { useNavigate } from 'react-router-dom';
import { getMyMedicalRecords, uploadMedicalDocument, downloadMedicalDocument } from '../services/medicalService';

const ROLE_DISPLAY = {
  ClubManager: 'Club Manager', TeamManager: 'Team Manager', Coach: 'Coach',
  FitnessCoach: 'Fitness Coach', TeamAnalyst: 'Analyst', TeamDoctor: 'Doctor',
  Player: 'Player', Admin: 'Admin',
};

export default function ProfilePage() {
  const { isDark, toggleTheme } = useTheme();
  const { currentUser, logout, isAdmin } = useAuth();
  const { clubs, teams, activeTeamId } = useClub();
  const navigate = useNavigate();
  const [medicalRecords, setMedicalRecords] = useState([]);
  const [medicalLoading, setMedicalLoading] = useState(false);
  const [medicalError, setMedicalError] = useState('');
  const [uploadingRequestId, setUploadingRequestId] = useState(null);

  const handleLogout = async () => { await logout(); navigate('/login', { replace: true }); };
  const rolesDisplay = currentUser?.roles?.map((r) => ROLE_DISPLAY[r] || r) || [];
  const isPlayer = currentUser?.roles?.includes('Player');
  const clubGroups = [
    ...clubs.map((club) => ({
      clubId: club.clubId,
      name: club.name,
      teams: teams.filter((team) => team.clubId === club.clubId),
    })),
    ...Object.values(
      teams
        .filter((team) => !clubs.some((club) => club.clubId === team.clubId))
        .reduce((acc, team) => {
          const key = team.clubId || 'unknown';
          if (!acc[key]) acc[key] = { clubId: key, name: team.clubName || 'Club', teams: [] };
          acc[key].teams.push(team);
          return acc;
        }, {})
    ),
  ];

  const loadMyMedicalRecords = async () => {
    if (!isPlayer) return;
    setMedicalLoading(true);
    setMedicalError('');
    try {
      const data = await getMyMedicalRecords();
      setMedicalRecords(data || []);
    } catch (err) {
      setMedicalRecords([]);
      setMedicalError(err.response?.data?.error || 'Failed to load medical records');
    } finally {
      setMedicalLoading(false);
    }
  };

  useEffect(() => {
    if (isPlayer && currentUser?.userId && activeTeamId) {
      navigate(`/app/members/${currentUser.userId}`, { replace: true });
      return;
    }
    loadMyMedicalRecords();
  }, [isPlayer, currentUser?.userId, activeTeamId]);

  const handleUploadDocument = async (requestId, event) => {
    const file = event.target.files?.[0];
    if (!file) return;

    setUploadingRequestId(requestId);
    setMedicalError('');
    try {
      await uploadMedicalDocument(requestId, file);
      await loadMyMedicalRecords();
    } catch (err) {
      setMedicalError(err.response?.data?.error || 'Failed to upload document');
    } finally {
      setUploadingRequestId(null);
      event.target.value = '';
    }
  };

  return (
    <PageTransition className="flex-1">
      <TopBar title="Profile" />
      <div className="px-4 md:px-6 lg:px-8 pb-24 lg:pb-8 max-w-3xl mx-auto w-full">
        <div className={`rounded-2xl p-6 md:p-8 flex flex-col items-center gap-3 mb-6 ${isDark ? 'bg-surface-dark' : 'bg-white shadow-sm'}`}>
          <Avatar alt={currentUser?.name} size="xl" />
          <h2 className={`text-xl md:text-2xl font-bold ${isDark ? 'text-white' : 'text-black'}`}>{currentUser?.name || 'User'}</h2>
          <div className="flex flex-wrap justify-center gap-2">
            {isAdmin && <span className="px-4 py-1.5 rounded-pill bg-red-500/20 text-red-500 text-sm font-semibold">Admin</span>}
            {rolesDisplay.map((r) => <span key={r} className="px-4 py-1.5 rounded-pill bg-primary/20 text-primary text-sm font-semibold">{r}</span>)}
          </div>
          <p className={`text-sm ${isDark ? 'text-white/50' : 'text-gray-500'}`}>{currentUser?.email}</p>
        </div>

        {clubGroups.length > 0 && (
          <div className={`rounded-2xl p-5 mb-3 ${isDark ? 'bg-surface-dark' : 'bg-white shadow-sm'}`}>
            <h3 className={`font-semibold text-body mb-3 ${isDark ? 'text-white' : 'text-black'}`}>My Clubs & Teams</h3>
            {clubGroups.map((c) => (
              <div key={c.clubId} className="mb-2">
                <div className="flex items-center gap-2 mb-1">
                  <Building2 size={16} className="text-primary" />
                  <span className={`text-sm font-medium ${isDark ? 'text-white' : 'text-black'}`}>{c.name}</span>
                </div>
                {c.teams.map((t) => (
                  <p key={t.teamId} className={`text-body-sm ml-6 ${isDark ? 'text-white/40' : 'text-gray-400'}`}>- {t.teamName} ({t.memberCount} members)</p>
                ))}
              </div>
            ))}
          </div>
        )}

        {isPlayer && (
          <div className={`rounded-2xl p-5 mb-3 ${isDark ? 'bg-surface-dark' : 'bg-white shadow-sm'}`}>
            <div className="flex items-center justify-between gap-3 mb-3">
              <div className="flex items-center gap-2">
                <Heart size={18} className="text-red-500" />
                <h3 className={`font-semibold text-body ${isDark ? 'text-white' : 'text-black'}`}>Medical Records</h3>
              </div>
              {medicalLoading && <span className={`text-xs ${isDark ? 'text-white/40' : 'text-gray-400'}`}>Loading...</span>}
            </div>

            {medicalError && (
              <div className="mb-3 p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{medicalError}</div>
            )}

            {!medicalLoading && medicalRecords.length === 0 && (
              <p className={`text-body-sm ${isDark ? 'text-white/40' : 'text-gray-400'}`}>No medical records yet.</p>
            )}

            <div className="space-y-3">
              {medicalRecords.map((record) => (
                <div key={record.recordId} className={`p-3 rounded-card border ${isDark ? 'border-white/10 bg-white/5' : 'border-gray-100 bg-gray-50'}`}>
                  <div className="flex items-center justify-between gap-2">
                    <span className={`text-sm font-semibold ${isDark ? 'text-white' : 'text-black'}`}>{record.injuryType || 'Medical Record'}</span>
                    <span className={`text-[10px] px-2 py-0.5 rounded-pill ${record.isCleared ? 'bg-green-500/10 text-green-500' : 'bg-red-500/10 text-red-500'}`}>
                      {record.isCleared ? 'Cleared' : 'Not Cleared'}
                    </span>
                  </div>
                  {record.diagnosis && <p className={`text-xs mt-1 ${isDark ? 'text-white/60' : 'text-gray-600'}`}>{record.diagnosis}</p>}
                  {record.recoveryTips && (
                    <div className={`mt-3 p-3 rounded-card ${isDark ? 'bg-black/20' : 'bg-white'}`}>
                      <p className={`text-badge mb-1 ${isDark ? 'text-white/40' : 'text-gray-400'}`}>Recovery Tips</p>
                      <p className={`text-xs ${isDark ? 'text-white/70' : 'text-gray-700'}`}>{record.recoveryTips}</p>
                    </div>
                  )}
                  {record.documentRequests?.length > 0 && (
                    <div className="mt-3 space-y-2">
                      {record.documentRequests.map((request) => (
                        <div key={request.requestId} className={`p-3 rounded-card ${isDark ? 'bg-black/20' : 'bg-white'}`}>
                          <div className="flex items-center justify-between gap-2">
                            <div className="flex items-center gap-2 min-w-0">
                              <FileText size={14} className={request.status === 'Uploaded' ? 'text-green-500' : 'text-blue-500'} />
                              <span className={`text-xs font-semibold truncate ${isDark ? 'text-white' : 'text-black'}`}>{request.documentName}</span>
                            </div>
                            <span className={`text-[10px] px-2 py-0.5 rounded-pill ${request.status === 'Uploaded' ? 'bg-green-500/10 text-green-500' : 'bg-blue-500/10 text-blue-500'}`}>
                              {request.status}
                            </span>
                          </div>
                          {request.note && <p className={`text-xs mt-1 ${isDark ? 'text-white/50' : 'text-gray-500'}`}>{request.note}</p>}
                          {request.status === 'Pending' && (
                            <label className="inline-flex items-center gap-1 mt-2 px-3 py-2 rounded-card bg-primary text-white text-xs font-semibold hover:bg-primary-dark transition-colors cursor-pointer">
                              <Upload size={12} />{uploadingRequestId === request.requestId ? 'Uploading...' : 'Upload Document'}
                              <input type="file" className="hidden" disabled={uploadingRequestId === request.requestId}
                                onChange={(event) => handleUploadDocument(request.requestId, event)}
                                id={`input-upload-medical-document-${request.requestId}`} />
                            </label>
                          )}
                          {request.status === 'Uploaded' && (
                            <button type="button" onClick={() => downloadMedicalDocument(request.requestId, request.originalFileName || request.documentName)}
                              className="inline-flex items-center gap-1 mt-2 text-xs font-semibold text-primary"
                              id={`link-player-download-medical-document-${request.requestId}`}>
                              <Download size={12} />View uploaded document
                            </button>
                          )}
                        </div>
                      ))}
                    </div>
                  )}
                  <p className={`text-[10px] mt-2 ${isDark ? 'text-white/30' : 'text-gray-400'}`}>
                    {new Date(record.recordDate).toLocaleDateString()}
                    {record.expectedReturnDate ? ` - Return: ${record.expectedReturnDate}` : ''}
                  </p>
                </div>
              ))}
            </div>
          </div>
        )}

        <div className={`rounded-2xl overflow-hidden ${isDark ? 'bg-surface-dark' : 'bg-white shadow-sm'}`}>
          <button onClick={() => navigate('/app/settings')} className={`w-full flex items-center justify-between px-5 py-4 transition-colors ${isDark ? 'hover:bg-white/5' : 'hover:bg-gray-50'}`}>
            <span className={`text-[15px] font-medium ${isDark ? 'text-white' : 'text-black'}`}>Settings</span>
            <ChevronRight size={18} className={isDark ? 'text-white/40' : 'text-gray-400'} />
          </button>
        </div>

        <button onClick={toggleTheme} className={`w-full flex items-center justify-between px-5 py-4 rounded-2xl mt-3 transition-colors ${isDark ? 'bg-surface-dark hover:bg-white/5' : 'bg-white shadow-sm hover:bg-gray-50'}`} id="btn-theme-toggle-profile">
          <div className="flex items-center gap-3">
            {isDark ? <Sun size={20} className="text-yellow-400" /> : <Moon size={20} className="text-gray-600" />}
            <span className={`text-[15px] font-medium ${isDark ? 'text-white' : 'text-black'}`}>{isDark ? 'Light Mode' : 'Dark Mode'}</span>
          </div>
          <div className={`w-12 h-7 rounded-full relative transition-colors ${isDark ? 'bg-primary' : 'bg-gray-300'}`}>
            <div className={`w-5 h-5 rounded-full bg-white absolute top-1 transition-transform duration-200 ${isDark ? 'translate-x-6' : 'translate-x-1'}`} />
          </div>
        </button>

        <button onClick={handleLogout} className="w-full flex items-center justify-center gap-2 px-5 py-4 rounded-2xl mt-3 bg-red-500/10 text-red-500 font-semibold transition-colors hover:bg-red-500/20" id="btn-logout">
          <LogOut size={20} /><span>Log Out</span>
        </button>
      </div>
    </PageTransition>
  );
}
