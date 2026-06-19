import { useState, useEffect } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router-dom';
import TopBar from '../components/TopBar';
import PageTransition from '../components/PageTransition';
import Avatar from '../components/Avatar';
import LoadingSpinner from '../components/LoadingSpinner';
import Modal from '../components/Modal';
import FormInput from '../components/FormInput';
import SelectField from '../components/SelectField';
import useTheme from '../hooks/useTheme';
import useAuth from '../hooks/useAuth';
import useClub from '../hooks/useClub';
import { getPlayerProfile } from '../services/playerService';
import { createConversation } from '../services/messagingService';
import { getPlayerMedicalRecords, getMyMedicalRecords, createMedicalRecord, updateMedicalRecord, updateMedicalClearance, requestMedicalDocument, uploadMedicalDocument, downloadMedicalDocument } from '../services/medicalService';
import { getPlayerFitnessRecords, getMyFitnessRecords, createFitnessRecord } from '../services/fitnessService';
import { getPlayerStats, getPlayerMatchHistory } from '../services/statsService';
import { getTeamEvents } from '../services/eventService';
import { getEventAttendance, getMyAttendance } from '../services/attendanceService';
import { getRoleAccess } from '../utils/roleAccess';
import { MessageSquare, Heart, Activity, ShieldCheck, ShieldAlert, Plus, Edit3, FileText, Send, Download, Upload, BarChart3, ClipboardCheck } from 'lucide-react';

const FITNESS_TEST_OPTIONS = ['BMI', 'Body Fat %', 'Speed Test', 'Endurance Score', 'Other'];
const FITNESS_TEST_VALUES = ['bmi', 'bodyFatPct', 'speedTestResult', 'enduranceScore', 'other'];

const blankFitnessForm = () => ({
  testDate: new Date().toISOString().slice(0, 10),
  testType: '',
  result: '',
  customTestName: '',
});

const blankMedicalForm = () => ({
  recordDate: new Date().toISOString().slice(0, 10),
  injuryType: '',
  diagnosis: '',
  expectedReturnDate: '',
  recoveryTips: '',
});

export default function MemberDetailPage() {
  const { id } = useParams();
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const { isDark } = useTheme();
  const { currentUser, isAdmin } = useAuth();
  const { activeClubId, activeTeamId, teams } = useClub();
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [startingChat, setStartingChat] = useState(false);
  const [tab, setTab] = useState('profile');
  const [medicalRecords, setMedicalRecords] = useState([]);
  const [fitnessRecords, setFitnessRecords] = useState([]);
  const [playerStats, setPlayerStats] = useState(null);
  const [playerMatchHistory, setPlayerMatchHistory] = useState([]);
  const [attendanceHistory, setAttendanceHistory] = useState([]);
  const [dataLoading, setDataLoading] = useState(false);

  // Write-form modals
  const [showFitnessForm, setShowFitnessForm] = useState(false);
  const [showMedicalForm, setShowMedicalForm] = useState(false);
  const [showDocumentRequestForm, setShowDocumentRequestForm] = useState(false);
  const [selectedMedicalRecord, setSelectedMedicalRecord] = useState(null);
  const [saving, setSaving] = useState(false);
  const [uploadingRequestId, setUploadingRequestId] = useState(null);
  const [formError, setFormError] = useState('');

  const [fitnessForm, setFitnessForm] = useState(blankFitnessForm);
  const [medicalForm, setMedicalForm] = useState(blankMedicalForm);
  const [documentRequestForm, setDocumentRequestForm] = useState({ documentName: '', note: '' });

  const activeTeam = teams.find((t) => t.teamId === activeTeamId);

  // Derive role on active team
  const access = getRoleAccess(currentUser, isAdmin);
  const canWriteFitness = access.canWriteFitness;
  const canWriteMedical = access.canWriteMedical;
  const isOwnProfile = id === currentUser?.userId;
  const blockedPlayerProfile = access.isPlayer && !isOwnProfile;

  const visibleTabs = [
    'profile',
    access.canViewMedical ? 'medical' : null,
    access.canViewFitness ? 'fitness' : null,
    access.canViewStats ? 'stats' : null,
    'attendance',
  ].filter(Boolean);

  useEffect(() => {
    const requested = searchParams.get('tab');
    if (requested && visibleTabs.includes(requested)) {
      setTab(requested);
    } else if (!requested && tab === 'profile') {
      if (access.isFitnessCoach) setTab('fitness');
      else if (access.isDoctor) setTab('medical');
      else if (access.isAnalyst) setTab('stats');
    }
  }, [searchParams, access.isFitnessCoach, access.isDoctor, access.isAnalyst, visibleTabs.join('|')]);

  useEffect(() => {
    if (!activeClubId || !activeTeamId || !id || blockedPlayerProfile) { setLoading(false); return; }
    let cancelled = false;
    const fetch = async () => {
      setLoading(true);
      try {
        const data = await getPlayerProfile(activeClubId, activeTeamId, id);
        if (!cancelled) setProfile(data);
      } catch {
        if (!cancelled) setProfile(null);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    fetch();
    return () => { cancelled = true; };
  }, [activeClubId, activeTeamId, id]);

  // Lazy-load medical/fitness
  const loadMedical = async () => {
    if (!activeClubId || !activeTeamId || !id) return;
    setDataLoading(true);
    try {
      const d = access.isPlayer && isOwnProfile
        ? await getMyMedicalRecords()
        : await getPlayerMedicalRecords(activeClubId, activeTeamId, id);
      setMedicalRecords(d || []);
    } catch { setMedicalRecords([]); }
    finally { setDataLoading(false); }
  };

  const loadFitness = async () => {
    if (!activeClubId || !activeTeamId || !id) return;
    setDataLoading(true);
    try {
      const d = access.isPlayer && isOwnProfile
        ? await getMyFitnessRecords()
        : await getPlayerFitnessRecords(activeClubId, activeTeamId, id);
      setFitnessRecords(d || []);
    } catch { setFitnessRecords([]); }
    finally { setDataLoading(false); }
  };

  const loadStats = async () => {
    if (!activeClubId || !activeTeamId || !id) return;
    setDataLoading(true);
    try {
      const [aggregate, history] = await Promise.all([
        getPlayerStats(activeClubId, activeTeamId, id).catch(() => null),
        getPlayerMatchHistory(activeClubId, activeTeamId, id).catch(() => []),
      ]);
      setPlayerStats(aggregate);
      setPlayerMatchHistory(history || []);
    } finally { setDataLoading(false); }
  };

  const loadAttendance = async () => {
    if (!activeClubId || !activeTeamId || !id) return;
    setDataLoading(true);
    try {
      const eventData = await getTeamEvents(activeClubId, activeTeamId).catch(() => []);
      const rows = await Promise.all((eventData || []).map(async (event) => {
        try {
          const attendance = isOwnProfile
            ? await getMyAttendance(activeClubId, activeTeamId, event.eventId)
            : (await getEventAttendance(activeClubId, activeTeamId, event.eventId)).find((row) => row.playerUserId === id);
          return attendance ? { ...attendance, eventTitle: event.title, eventType: event.eventType, eventStartAt: event.startAt } : null;
        } catch { return null; }
      }));
      setAttendanceHistory(rows.filter(Boolean).sort((a, b) => new Date(b.eventStartAt) - new Date(a.eventStartAt)));
    } finally { setDataLoading(false); }
  };

  useEffect(() => {
    if (tab === 'medical') loadMedical();
    if (tab === 'fitness') loadFitness();
    if (tab === 'stats') loadStats();
    if (tab === 'attendance') loadAttendance();
  }, [tab, activeClubId, activeTeamId, id]);

  const handleMessage = async () => {
    if (!id || startingChat) return;
    setStartingChat(true);
    try {
      const conversation = await createConversation({ participantUserIds: [id], isGroup: false });
      navigate(`/app/messages/${conversation.conversationId}`);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to start conversation');
    } finally {
      setStartingChat(false);
    }
  };

  // ----- Write handlers -----
  const numberOrNull = (v) => v === '' ? null : Number(v);
  const formatDateInput = (value) => value ? new Date(value).toISOString().slice(0, 10) : '';

  const openMedicalForm = (record = null) => {
    setFormError('');
    setSelectedMedicalRecord(record);
    setMedicalForm(record ? {
      recordDate: formatDateInput(record.recordDate),
      injuryType: record.injuryType || '',
      diagnosis: record.diagnosis || '',
      expectedReturnDate: record.expectedReturnDate || '',
      recoveryTips: record.recoveryTips || '',
    } : blankMedicalForm());
    setShowMedicalForm(true);
  };

  const openDocumentRequestForm = (record) => {
    setFormError('');
    setSelectedMedicalRecord(record);
    setDocumentRequestForm({ documentName: '', note: '' });
    setShowDocumentRequestForm(true);
  };

  const getFitnessMeasurements = (record) => {
    const values = [];
    if (record.bmi != null) values.push({ label: 'BMI', value: record.bmi });
    if (record.bodyFatPct != null) values.push({ label: 'Body Fat %', value: `${record.bodyFatPct}%` });
    if (record.speedTestResult != null) values.push({ label: 'Speed Test', value: record.speedTestResult });
    if (record.enduranceScore != null) values.push({ label: 'Endurance', value: record.enduranceScore });
    if (record.customTestName && record.customTestResult != null) values.push({ label: record.customTestName, value: record.customTestResult });
    return values;
  };

  const handleSaveFitness = async () => {
    setFormError('');
    if (!fitnessForm.testType) {
      setFormError('Please choose a test type'); return;
    }
    if (fitnessForm.result === '') {
      setFormError('Please enter a test result'); return;
    }
    if (fitnessForm.testType === 'other' && !fitnessForm.customTestName.trim()) {
      setFormError('Please enter the custom test name'); return;
    }
    setSaving(true);
    try {
      const request = {
        testDate: fitnessForm.testDate ? new Date(fitnessForm.testDate).toISOString() : null,
      };
      if (fitnessForm.testType === 'other') {
        request.customTestName = fitnessForm.customTestName.trim();
        request.customTestResult = numberOrNull(fitnessForm.result);
      } else {
        request[fitnessForm.testType] = numberOrNull(fitnessForm.result);
      }

      await createFitnessRecord(activeClubId, activeTeamId, id, {
        ...request,
      });
      setShowFitnessForm(false);
      setFitnessForm(blankFitnessForm());
      await loadFitness();
    } catch (err) {
      setFormError(err.response?.data?.error || 'Failed to save fitness record');
    } finally { setSaving(false); }
  };

  const handleSaveMedical = async () => {
    setFormError('');
    if (!medicalForm.injuryType.trim() && !medicalForm.diagnosis.trim()) {
      setFormError('Please add an injury type or diagnosis'); return;
    }
    setSaving(true);
    try {
      const request = {
        recordDate: medicalForm.recordDate ? new Date(medicalForm.recordDate).toISOString() : null,
        injuryType: medicalForm.injuryType.trim() || null,
        diagnosis: medicalForm.diagnosis.trim() || null,
        expectedReturnDate: medicalForm.expectedReturnDate || null,
        recoveryTips: medicalForm.recoveryTips.trim() || null,
      };
      if (selectedMedicalRecord) {
        await updateMedicalRecord(activeClubId, activeTeamId, selectedMedicalRecord.recordId, request);
      } else {
        await createMedicalRecord(activeClubId, activeTeamId, id, request);
      }
      setShowMedicalForm(false);
      setSelectedMedicalRecord(null);
      setMedicalForm(blankMedicalForm());
      await loadMedical();
    } catch (err) {
      setFormError(err.response?.data?.error || 'Failed to save medical record');
    } finally { setSaving(false); }
  };

  const handleRequestDocument = async () => {
    setFormError('');
    if (!selectedMedicalRecord) return;
    if (!documentRequestForm.documentName.trim()) {
      setFormError('Please enter the document name'); return;
    }
    setSaving(true);
    try {
      await requestMedicalDocument(activeClubId, activeTeamId, selectedMedicalRecord.recordId, {
        documentName: documentRequestForm.documentName.trim(),
        note: documentRequestForm.note.trim() || null,
      });
      setShowDocumentRequestForm(false);
      setSelectedMedicalRecord(null);
      setDocumentRequestForm({ documentName: '', note: '' });
      await loadMedical();
    } catch (err) {
      setFormError(err.response?.data?.error || 'Failed to request document');
    } finally { setSaving(false); }
  };

  const handleToggleClearance = async (record) => {
    if (!canWriteMedical) return;
    try {
      const updated = await updateMedicalClearance(activeClubId, activeTeamId, record.recordId, { isCleared: !record.isCleared });
      setMedicalRecords((prev) => prev.map((r) => r.recordId === record.recordId ? { ...r, isCleared: updated.isCleared } : r));
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to update clearance');
    }
  };

  const handleUploadDocument = async (requestId, event) => {
    const file = event.target.files?.[0];
    if (!file) return;
    setUploadingRequestId(requestId);
    setError('');
    try {
      await uploadMedicalDocument(requestId, file);
      await loadMedical();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to upload document');
    } finally {
      setUploadingRequestId(null);
      event.target.value = '';
    }
  };

  if (loading) {
    return (
      <PageTransition className="flex-1">
        <TopBar title="Member" showBack />
        <div className="flex justify-center py-12"><LoadingSpinner /></div>
      </PageTransition>
    );
  }

  if (blockedPlayerProfile) {
    return (
      <PageTransition className="flex-1">
        <TopBar title="Player Profile" showBack />
        <div className="px-4 py-10 max-w-3xl mx-auto w-full">
          <div className={`rounded-card p-6 text-center ${isDark ? 'bg-surface-dark text-white/60' : 'bg-white shadow-sm text-gray-500'}`}>
            Player profiles are private. You can only open your own dashboard.
          </div>
        </div>
      </PageTransition>
    );
  }

  return (
    <PageTransition className="flex-1">
      <TopBar title="Player Profile" showBack />
      <div className="px-4 pb-24 lg:pb-8 max-w-3xl mx-auto w-full">
        <div className={`text-xs mb-3 ${isDark ? 'text-white/40' : 'text-gray-500'}`}>
          Home / {activeTeam?.teamName || 'Team'} / {profile?.name || 'Player'}
        </div>
        {/* Hero card */}
        <div className={`rounded-2xl p-6 flex flex-col items-center gap-3 mb-6 ${isDark ? 'bg-surface-dark' : 'bg-white shadow-sm'}`}>
          <Avatar alt={profile?.name || 'Member'} size="xl" />
          <h2 className={`text-card-title ${isDark ? 'text-white' : 'text-black'}`}>{profile?.name || 'Team Member'}</h2>
          {profile?.position && (
            <div className="flex gap-2">
              <span className="px-3 py-1 rounded-pill bg-primary/20 text-primary text-sm font-semibold">{profile.position}</span>
              {profile.jerseyNumber != null && (
                <span className="px-3 py-1 rounded-pill bg-blue-500/20 text-blue-500 text-sm font-semibold">#{profile.jerseyNumber}</span>
              )}
            </div>
          )}
          {!isOwnProfile && (
            <button onClick={handleMessage} disabled={startingChat}
              className="mt-2 flex items-center gap-2 px-4 py-2.5 rounded-card bg-primary text-white text-sm font-semibold hover:bg-primary-dark transition-colors disabled:opacity-60"
              id="btn-message-member">
              <MessageSquare size={16} />{startingChat ? 'Opening...' : 'Message'}
            </button>
          )}
        </div>

        {error && (
          <div className="mb-4 p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{error}</div>
        )}

        {/* Tabs */}
        <div className="flex gap-2 overflow-x-auto pb-3 -mx-4 px-4 lg:mx-0 lg:px-0 mb-4">
          {visibleTabs.map((t) => (
            <button key={t} onClick={() => setTab(t)}
              className={`px-4 py-2 rounded-pill text-sm font-medium whitespace-nowrap transition-all duration-200 ${
                tab === t ? 'bg-primary text-white shadow-md'
                  : isDark ? 'bg-surface-dark text-white/70 hover:bg-white/10'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}>{tabLabel(t, access.isPlayer)}</button>
          ))}
        </div>

        {/* ========== Profile tab ========== */}
        {tab === 'profile' && profile && (
          <div className={`rounded-2xl p-5 ${isDark ? 'bg-surface-dark' : 'bg-white shadow-sm'}`}>
            <h3 className={`font-display text-section uppercase mb-3 ${isDark ? 'text-white' : 'text-black'}`}>Profile</h3>
            <div className="grid grid-cols-2 gap-3">
              {profile.height != null && (
                <div>
                  <p className={`text-badge ${isDark ? 'text-white/40' : 'text-gray-400'}`}>Height</p>
                  <p className={`text-body font-medium ${isDark ? 'text-white' : 'text-black'}`}>{profile.height} cm</p>
                </div>
              )}
              {profile.weight != null && (
                <div>
                  <p className={`text-badge ${isDark ? 'text-white/40' : 'text-gray-400'}`}>Weight</p>
                  <p className={`text-body font-medium ${isDark ? 'text-white' : 'text-black'}`}>{profile.weight} kg</p>
                </div>
              )}
              {profile.preferredFoot && (
                <div>
                  <p className={`text-badge ${isDark ? 'text-white/40' : 'text-gray-400'}`}>Preferred Foot</p>
                  <p className={`text-body font-medium ${isDark ? 'text-white' : 'text-black'}`}>{profile.preferredFoot}</p>
                </div>
              )}
              {activeTeam && (
                <div>
                  <p className={`text-badge ${isDark ? 'text-white/40' : 'text-gray-400'}`}>Team</p>
                  <p className={`text-body font-medium ${isDark ? 'text-white' : 'text-black'}`}>{activeTeam.teamName}</p>
                </div>
              )}
            </div>
          </div>
        )}
        {tab === 'profile' && !profile && !error && (
          <div className={`rounded-2xl p-5 text-center ${isDark ? 'bg-surface-dark' : 'bg-white shadow-sm'}`}>
            <p className={`text-body ${isDark ? 'text-white/50' : 'text-gray-500'}`}>No detailed profile available for this member.</p>
          </div>
        )}

        {/* ========== Medical tab ========== */}
        {tab === 'medical' && (
          <div>
            {/* Write button for TeamDoctor */}
            {canWriteMedical && (
              <div className="flex justify-end mb-3">
                <button onClick={() => openMedicalForm()}
                  className="flex items-center gap-2 px-4 py-2.5 rounded-card bg-primary text-white text-sm font-semibold hover:bg-primary-dark transition-colors"
                  id="btn-add-medical">
                  <Plus size={16} />Add Medical Record
                </button>
              </div>
            )}
            {dataLoading && <SkeletonList isDark={isDark} />}
            {!dataLoading && medicalRecords.length === 0 && (
              <div className={`rounded-2xl p-5 text-center ${isDark ? 'bg-surface-dark' : 'bg-white shadow-sm'}`}>
                <Heart size={32} className={`mx-auto mb-2 ${isDark ? 'text-white/30' : 'text-gray-300'}`} />
                <p className={`text-body ${isDark ? 'text-white/50' : 'text-gray-500'}`}>No medical records found</p>
              </div>
            )}
            {!dataLoading && medicalRecords.length > 0 && (
              <div className="space-y-2">
                {medicalRecords.map((r) => (
                  <div key={r.recordId} className={`p-4 rounded-card shadow-sm ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
                    <div className="flex items-center justify-between mb-1">
                      <div className="flex items-center gap-2 flex-wrap justify-end">
                        {r.isCleared
                          ? <ShieldCheck size={16} className="text-green-500" />
                          : <ShieldAlert size={16} className="text-red-500" />}
                        <span className={`font-semibold text-sm ${isDark ? 'text-white' : 'text-black'}`}>
                          {r.injuryType || 'Medical Record'}
                        </span>
                      </div>
                      <div className="flex items-center gap-2">
                        {canWriteMedical && (
                          <>
                            <button onClick={() => openMedicalForm(r)}
                              className="text-xs px-2 py-1 rounded-pill font-medium bg-primary/10 text-primary hover:bg-primary/20 transition-colors flex items-center gap-1"
                              id={`btn-edit-medical-${r.recordId}`}>
                              <Edit3 size={12} />Edit
                            </button>
                            <button onClick={() => openDocumentRequestForm(r)}
                              className="text-xs px-2 py-1 rounded-pill font-medium bg-blue-500/10 text-blue-500 hover:bg-blue-500/20 transition-colors flex items-center gap-1"
                              id={`btn-request-medical-document-${r.recordId}`}>
                              <FileText size={12} />Request
                            </button>
                            <button onClick={() => handleToggleClearance(r)}
                              className={`text-xs px-2 py-1 rounded-pill font-medium transition-colors ${
                                r.isCleared
                                  ? 'bg-green-500/10 text-green-500 hover:bg-green-500/20'
                                  : 'bg-red-500/10 text-red-500 hover:bg-red-500/20'
                              }`}
                              id={`btn-toggle-clearance-${r.recordId}`}>
                              {r.isCleared ? 'Cleared' : 'Mark Cleared'}
                            </button>
                          </>
                        )}
                        {!canWriteMedical && (
                          <span className={`text-xs px-2 py-0.5 rounded-pill ${r.isCleared ? 'bg-green-500/10 text-green-500' : 'bg-red-500/10 text-red-500'}`}>
                            {r.isCleared ? 'Cleared' : 'Not Cleared'}
                          </span>
                        )}
                      </div>
                    </div>
                    {r.diagnosis && <p className={`text-xs mt-1 ${isDark ? 'text-white/60' : 'text-gray-600'}`}>{r.diagnosis}</p>}
                    {r.recoveryTips && (
                      <div className={`mt-3 p-3 rounded-card ${isDark ? 'bg-white/5' : 'bg-gray-50'}`}>
                        <p className={`text-badge mb-1 ${isDark ? 'text-white/40' : 'text-gray-400'}`}>Recovery Tips</p>
                        <p className={`text-xs ${isDark ? 'text-white/70' : 'text-gray-700'}`}>{r.recoveryTips}</p>
                      </div>
                    )}
                    {r.documentRequests?.length > 0 && (
                      <div className="mt-3 space-y-2">
                        {r.documentRequests.map((request) => (
                          <div key={request.requestId} className={`p-3 rounded-card border ${isDark ? 'border-white/10 bg-white/5' : 'border-gray-100 bg-gray-50'}`}>
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
                            {access.isPlayer && isOwnProfile && request.status === 'Pending' && (
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
                                id={`link-download-medical-document-${request.requestId}`}>
                                <Download size={12} />View document
                              </button>
                            )}
                          </div>
                        ))}
                      </div>
                    )}
                    <div className={`flex gap-4 text-[10px] mt-2 ${isDark ? 'text-white/30' : 'text-gray-400'}`}>
                      <span>{new Date(r.recordDate).toLocaleDateString()}</span>
                      {r.expectedReturnDate && <span>Return: {r.expectedReturnDate}</span>}
                      {r.doctorName && <span>Dr. {r.doctorName}</span>}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* ========== Fitness tab ========== */}
        {tab === 'fitness' && (
          <div>
            {/* Write button for FitnessCoach */}
            {canWriteFitness && (
              <div className="flex justify-end mb-3">
                <button onClick={() => { setFormError(''); setFitnessForm(blankFitnessForm()); setShowFitnessForm(true); }}
                  className="flex items-center gap-2 px-4 py-2.5 rounded-card bg-primary text-white text-sm font-semibold hover:bg-primary-dark transition-colors"
                  id="btn-add-fitness">
                  <Plus size={16} />Log Fitness Test
                </button>
              </div>
            )}
            {dataLoading && <SkeletonList isDark={isDark} />}
            {!dataLoading && fitnessRecords.length === 0 && (
              <div className={`rounded-2xl p-5 text-center ${isDark ? 'bg-surface-dark' : 'bg-white shadow-sm'}`}>
                <Activity size={32} className={`mx-auto mb-2 ${isDark ? 'text-white/30' : 'text-gray-300'}`} />
                <p className={`text-body ${isDark ? 'text-white/50' : 'text-gray-500'}`}>No fitness records found</p>
              </div>
            )}
            {!dataLoading && fitnessRecords.length > 0 && (
              <div className="space-y-2">
                {fitnessRecords.map((r) => (
                  <div key={r.fitnessId} className={`p-4 rounded-card shadow-sm ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
                    <div className="flex items-center justify-between mb-1">
                      <span className={`font-semibold text-sm ${isDark ? 'text-white' : 'text-black'}`}>
                        Fitness Test - {new Date(r.testDate).toLocaleDateString()}
                      </span>
                    </div>
                    <div className="grid grid-cols-2 gap-2 mt-2">
                      {getFitnessMeasurements(r).map((metric) => (
                        <div key={metric.label}>
                          <p className={`text-badge ${isDark ? 'text-white/40' : 'text-gray-400'}`}>{metric.label}</p>
                          <p className={`text-body font-medium ${isDark ? 'text-white' : 'text-black'}`}>{metric.value}</p>
                        </div>
                      ))}
                    </div>
                    {r.fitnessUserName && (
                      <p className={`text-[10px] mt-2 ${isDark ? 'text-white/30' : 'text-gray-400'}`}>Recorded by {r.fitnessUserName}</p>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* ========== Stats tab ========== */}
        {tab === 'stats' && (
          <div>
            {dataLoading && <SkeletonList isDark={isDark} />}
            {!dataLoading && (
              <div className="space-y-3">
                <div className={`rounded-card p-4 shadow-sm ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
                  <div className="flex items-center gap-2 mb-3">
                    <BarChart3 size={18} className="text-primary" />
                    <h3 className={`font-semibold ${isDark ? 'text-white' : 'text-black'}`}>Cumulative Stats</h3>
                  </div>
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                    <ProfileMetric label="Events" value={playerStats?.eventsPlayed ?? 0} isDark={isDark} />
                    <ProfileMetric label="Minutes" value={playerStats?.minutesPlayed ?? 0} isDark={isDark} />
                    <ProfileMetric label="Goals" value={playerStats?.goals ?? 0} isDark={isDark} />
                    <ProfileMetric label="Assists" value={playerStats?.assists ?? 0} isDark={isDark} />
                    <ProfileMetric label="Shots" value={`${playerStats?.shotsOnTarget ?? 0}/${playerStats?.totalShots ?? 0}`} isDark={isDark} />
                    <ProfileMetric label="Pass %" value={playerStats?.averagePassAccuracy != null ? `${Number(playerStats.averagePassAccuracy).toFixed(1)}%` : '-'} isDark={isDark} />
                    <ProfileMetric label="Tackles" value={playerStats?.tackles ?? 0} isDark={isDark} />
                    <ProfileMetric label="Rating" value={playerStats?.averageRating != null ? Number(playerStats.averageRating).toFixed(1) : '-'} isDark={isDark} />
                  </div>
                </div>

                <div className={`rounded-card p-4 shadow-sm ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
                  <h3 className={`font-semibold mb-3 ${isDark ? 'text-white' : 'text-black'}`}>Match History</h3>
                  {playerMatchHistory.length === 0 && <p className={`text-sm ${isDark ? 'text-white/45' : 'text-gray-500'}`}>No player stats recorded yet.</p>}
                  {playerMatchHistory.map((row) => (
                    <div key={row.playerMatchStatsId} className={`p-3 rounded-card mb-2 ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
                      <div className="flex items-center justify-between gap-3">
                        <p className={`text-sm font-semibold ${isDark ? 'text-white' : 'text-black'}`}>{row.eventTitle}</p>
                        <span className="text-xs text-primary">{row.goals ?? 0} G / {row.assists ?? 0} A</span>
                      </div>
                      <p className={`text-xs mt-1 ${isDark ? 'text-white/45' : 'text-gray-500'}`}>
                        {new Date(row.eventStartAt).toLocaleDateString()} {row.opponentName ? `- vs ${row.opponentName}` : ''} - {row.minutesPlayed ?? 0} min
                      </p>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {/* ========== Attendance tab ========== */}
        {tab === 'attendance' && (
          <div className={`rounded-card p-4 shadow-sm ${isDark ? 'bg-surface-dark' : 'bg-white'}`}>
            <div className="flex items-center gap-2 mb-3">
              <ClipboardCheck size={18} className="text-primary" />
              <h3 className={`font-semibold ${isDark ? 'text-white' : 'text-black'}`}>Attendance History</h3>
            </div>
            {dataLoading && <SkeletonList isDark={isDark} />}
            {!dataLoading && attendanceHistory.length === 0 && <p className={`text-sm ${isDark ? 'text-white/45' : 'text-gray-500'}`}>No attendance history found.</p>}
            {!dataLoading && attendanceHistory.map((row) => (
              <div key={`${row.eventId}-${row.attendanceId || row.eventStartAt}`} className={`p-3 rounded-card mb-2 ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
                <div className="flex items-center justify-between gap-3">
                  <p className={`text-sm font-semibold ${isDark ? 'text-white' : 'text-black'}`}>{row.eventTitle || row.eventType}</p>
                  <span className="text-xs px-2 py-0.5 rounded-pill bg-primary/10 text-primary">{row.status}</span>
                </div>
                <p className={`text-xs mt-1 ${isDark ? 'text-white/45' : 'text-gray-500'}`}>{new Date(row.eventStartAt).toLocaleDateString()}{row.notes ? ` - ${row.notes}` : ''}</p>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* ===== Fitness Form Modal ===== */}
      <Modal isOpen={showFitnessForm} onClose={() => setShowFitnessForm(false)} title="Log Fitness Test">
        <div className="flex flex-col gap-3">
          {formError && <div className="p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{formError}</div>}
          <FormInput label="Test Date" type="date" value={fitnessForm.testDate}
            onChange={(e) => setFitnessForm({ ...fitnessForm, testDate: e.target.value })} id="input-fitness-date" />
          <SelectField label="Test Type *" value={fitnessForm.testType}
            onChange={(testType) => setFitnessForm({ ...fitnessForm, testType, result: '', customTestName: '' })}
            options={FITNESS_TEST_OPTIONS}
            optionValues={FITNESS_TEST_VALUES}
            id="select-fitness-test-type" />
          {fitnessForm.testType === 'other' && (
            <FormInput label="Custom Test Name *" value={fitnessForm.customTestName}
              onChange={(e) => setFitnessForm({ ...fitnessForm, customTestName: e.target.value })} id="input-fitness-custom-name" />
          )}
          {fitnessForm.testType && (
            <FormInput label={fitnessForm.testType === 'other' ? 'Custom Test Result *' : 'Result *'}
              type="number"
              step="0.01"
              value={fitnessForm.result}
              onChange={(e) => setFitnessForm({ ...fitnessForm, result: e.target.value })}
              id="input-fitness-result" />
          )}
          <button onClick={handleSaveFitness} disabled={saving}
            className="w-full py-3 rounded-card bg-primary text-white font-semibold hover:bg-primary-dark transition-colors disabled:opacity-60"
            id="btn-save-fitness">
            {saving ? 'Saving...' : 'Save Fitness Record'}
          </button>
        </div>
      </Modal>

      {/* ===== Medical Form Modal ===== */}
      <Modal isOpen={showMedicalForm} onClose={() => { setShowMedicalForm(false); setSelectedMedicalRecord(null); }} title={selectedMedicalRecord ? 'Edit Medical Record' : 'Add Medical Record'}>
        <div className="flex flex-col gap-3">
          {formError && <div className="p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{formError}</div>}
          <FormInput label="Record Date" type="date" value={medicalForm.recordDate}
            onChange={(e) => setMedicalForm({ ...medicalForm, recordDate: e.target.value })} id="input-medical-date" />
          <FormInput label="Injury Type *" value={medicalForm.injuryType}
            onChange={(e) => setMedicalForm({ ...medicalForm, injuryType: e.target.value })} id="input-medical-injury" />
          <div>
            <textarea value={medicalForm.diagnosis}
              onChange={(e) => setMedicalForm({ ...medicalForm, diagnosis: e.target.value })}
              placeholder="Diagnosis"
              rows={3}
              className={`w-full px-4 py-3 rounded-card border-2 text-body outline-none transition-colors resize-none ${
                isDark ? 'bg-surface-dark text-white border-accent/50 focus:border-accent placeholder:text-white/40'
                  : 'bg-white text-black border-accent/50 focus:border-accent placeholder:text-black/40'
              }`}
              id="input-medical-diagnosis" />
          </div>
          <FormInput label="Expected Return Date" type="date" value={medicalForm.expectedReturnDate}
            onChange={(e) => setMedicalForm({ ...medicalForm, expectedReturnDate: e.target.value })} id="input-medical-return" />
          <div>
            <textarea value={medicalForm.recoveryTips}
              onChange={(e) => setMedicalForm({ ...medicalForm, recoveryTips: e.target.value })}
              placeholder="Recovery Tips"
              rows={3}
              className={`w-full px-4 py-3 rounded-card border-2 text-body outline-none transition-colors resize-none ${
                isDark ? 'bg-surface-dark text-white border-accent/50 focus:border-accent placeholder:text-white/40'
                  : 'bg-white text-black border-accent/50 focus:border-accent placeholder:text-black/40'
              }`}
              id="input-medical-recovery-tips" />
          </div>
          <button onClick={handleSaveMedical} disabled={saving}
            className="w-full py-3 rounded-card bg-primary text-white font-semibold hover:bg-primary-dark transition-colors disabled:opacity-60"
            id="btn-save-medical">
            {saving ? 'Saving...' : selectedMedicalRecord ? 'Update Medical Record' : 'Save Medical Record'}
          </button>
        </div>
      </Modal>

      {/* ===== Document Request Modal ===== */}
      <Modal isOpen={showDocumentRequestForm} onClose={() => { setShowDocumentRequestForm(false); setSelectedMedicalRecord(null); }} title="Request Document">
        <div className="flex flex-col gap-3">
          {formError && <div className="p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{formError}</div>}
          <FormInput label="Document Name *" value={documentRequestForm.documentName}
            onChange={(e) => setDocumentRequestForm({ ...documentRequestForm, documentName: e.target.value })} id="input-medical-document-name" />
          <div>
            <textarea value={documentRequestForm.note}
              onChange={(e) => setDocumentRequestForm({ ...documentRequestForm, note: e.target.value })}
              placeholder="Request note"
              rows={3}
              className={`w-full px-4 py-3 rounded-card border-2 text-body outline-none transition-colors resize-none ${
                isDark ? 'bg-surface-dark text-white border-accent/50 focus:border-accent placeholder:text-white/40'
                  : 'bg-white text-black border-accent/50 focus:border-accent placeholder:text-black/40'
              }`}
              id="input-medical-document-note" />
          </div>
          <button onClick={handleRequestDocument} disabled={saving}
            className="w-full py-3 rounded-card bg-primary text-white font-semibold hover:bg-primary-dark transition-colors disabled:opacity-60 flex items-center justify-center gap-2"
            id="btn-send-medical-document-request">
            <Send size={16} />{saving ? 'Sending...' : 'Send Request'}
          </button>
        </div>
      </Modal>
    </PageTransition>
  );
}

function ProfileMetric({ label, value, isDark }) {
  return (
    <div className={`p-3 rounded-card ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
      <p className={`text-badge ${isDark ? 'text-white/40' : 'text-gray-500'}`}>{label}</p>
      <p className={`text-sm font-bold mt-1 ${isDark ? 'text-white' : 'text-black'}`}>{value}</p>
    </div>
  );
}

function tabLabel(tab, isPlayer) {
  if (tab === 'profile') return 'Overview';
  if (!isPlayer) return tab.charAt(0).toUpperCase() + tab.slice(1);
  return {
    stats: 'My Stats',
    fitness: 'My Fitness',
    medical: 'My Medical',
    attendance: 'My Attendance',
  }[tab] || 'Overview';
}

function SkeletonList({ isDark }) {
  return (
    <div className="space-y-2">
      {[0, 1, 2].map((item) => (
        <div key={item} className={`h-20 rounded-card animate-pulse ${isDark ? 'bg-white/10' : 'bg-gray-100'}`} />
      ))}
    </div>
  );
}
