import { useState, useEffect, useMemo } from 'react';
import { useSearchParams } from 'react-router-dom';
import TopBar from '../components/TopBar';
import PageTransition from '../components/PageTransition';
import EmptyState from '../components/EmptyState';
import LoadingSpinner from '../components/LoadingSpinner';
import Modal from '../components/Modal';
import FormInput from '../components/FormInput';
import SelectField from '../components/SelectField';
import useTheme from '../hooks/useTheme';
import useAuth from '../hooks/useAuth';
import useClub from '../hooks/useClub';
import { getTeamMembers } from '../services/teamService';
import { getTeamEvents } from '../services/eventService';
import { createLineup, createPlan, deleteLineup, deletePlan, getTeamLineups, getTeamPlans, updateLineup, updatePlan } from '../services/planService';
import { ClipboardList, Eye, FileText, Lock, Pencil, Plus, Trash2, Users } from 'lucide-react';

const VIS_BADGE = {
  Draft: { label: 'Draft', icon: Lock, color: 'text-gray-400 bg-gray-500/10' },
  TeamVisible: { label: 'Team', icon: Eye, color: 'text-blue-400 bg-blue-500/10' },
  PlayerAssigned: { label: 'Players', icon: Users, color: 'text-green-400 bg-green-500/10' },
};

const VISIBILITIES = ['Draft', 'TeamVisible', 'PlayerAssigned'];
const VISIBILITY_LABELS = ['Draft', 'Team visible', 'Player visible'];
const LINEUP_UNITS = ['Starting', 'Bench', 'Reserve'];
const emptyPlanForm = { title: '', description: '', content: '', visibility: 'Draft' };
const emptyLineupForm = { title: '', formation: '', eventId: '', gameModel: '', tacticalNotes: '', visibility: 'Draft', players: [] };

export default function PlansPage() {
  const { isDark } = useTheme();
  const [searchParams, setSearchParams] = useSearchParams();
  const { currentUser, isAdmin } = useAuth();
  const { activeClubId, activeTeamId, selectedTeam } = useClub();

  const isCoach = currentUser?.roles?.includes('Coach');
  const canCreate = isAdmin || isCoach;
  const [tab, setTab] = useState('Plans');
  const [plans, setPlans] = useState([]);
  const [lineups, setLineups] = useState([]);
  const [players, setPlayers] = useState([]);
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(false);
  const [showPlanForm, setShowPlanForm] = useState(false);
  const [showLineupForm, setShowLineupForm] = useState(false);
  const [viewingPlan, setViewingPlan] = useState(null);
  const [viewingLineup, setViewingLineup] = useState(null);
  const [editingPlan, setEditingPlan] = useState(null);
  const [editingLineup, setEditingLineup] = useState(null);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(null);
  const [error, setError] = useState('');
  const [planForm, setPlanForm] = useState(emptyPlanForm);
  const [lineupForm, setLineupForm] = useState(emptyLineupForm);

  const loadData = async (cancelledRef) => {
    if (!activeClubId || !activeTeamId) {
      setPlans([]);
      setLineups([]);
      return;
    }

    setLoading(true);
    try {
      const [planData, lineupData, memberData, eventData] = await Promise.all([
        getTeamPlans(activeClubId, activeTeamId),
        getTeamLineups(activeClubId, activeTeamId),
        getTeamMembers(activeClubId, activeTeamId),
        getTeamEvents(activeClubId, activeTeamId).catch(() => []),
      ]);
      if (cancelledRef?.cancelled) return;
      setPlans(planData || []);
      setLineups(lineupData || []);
      setPlayers((memberData || []).filter((m) => m.role === 'Player'));
      setEvents((eventData || []).filter((event) => event.eventType === 'Match' || event.eventType === 'Training'));
    } catch {
      if (!cancelledRef?.cancelled) {
        setPlans([]);
        setLineups([]);
      }
    } finally {
      if (!cancelledRef?.cancelled) setLoading(false);
    }
  };

  useEffect(() => {
    if (!activeClubId || !activeTeamId) {
      setPlans([]);
      setLineups([]);
      return;
    }

    const cancelledRef = { cancelled: false };
    loadData(cancelledRef);
    return () => { cancelledRef.cancelled = true; };
  }, [activeClubId, activeTeamId]);

  const eventOptions = useMemo(() => ['No linked event', ...events.map((event) => `${event.title} - ${event.eventType} - ${new Date(event.startAt).toLocaleDateString()}`)], [events]);
  const eventValues = useMemo(() => ['', ...events.map((event) => event.eventId)], [events]);

  const canEditPlan = (plan) => isAdmin || (isCoach && plan?.createdBy === currentUser?.userId);
  const canEditLineup = (lineup) => isAdmin || (isCoach && lineup?.createdBy === currentUser?.userId);

  const openCreatePlan = () => {
    setError('');
    setEditingPlan(null);
    setPlanForm(emptyPlanForm);
    setShowPlanForm(true);
  };

  useEffect(() => {
    const action = searchParams.get('action');
    if (action === 'create-plan' && canCreate) {
      setTab('Plans');
      openCreatePlan();
      setSearchParams({}, { replace: true });
    }
    if (action === 'create-lineup' && canCreate) {
      setTab('Lineups');
      openCreateLineup();
      setSearchParams({}, { replace: true });
    }
  }, [searchParams, canCreate, players]);

  const openCreateLineup = () => {
    setError('');
    setEditingLineup(null);
    setLineupForm({ ...emptyLineupForm, players: players.slice(0, 11).map((p, index) => blankLineupPlayer(p, index)) });
    setShowLineupForm(true);
  };

  const openEditPlan = (plan) => {
    setError('');
    setViewingPlan(null);
    setEditingPlan(plan);
    setPlanForm({ title: plan.title || '', description: plan.description || '', content: plan.content || '', visibility: plan.visibility || 'Draft' });
    setShowPlanForm(true);
  };

  const openEditLineup = (lineup) => {
    setError('');
    setViewingLineup(null);
    setEditingLineup(lineup);
    setLineupForm({
      title: lineup.title || '',
      formation: lineup.formation || '',
      eventId: lineup.eventId || '',
      gameModel: lineup.gameModel || '',
      tacticalNotes: lineup.tacticalNotes || '',
      visibility: lineup.visibility || 'Draft',
      players: (lineup.players || []).map((p, index) => ({
        playerUserId: p.playerUserId,
        playerName: p.playerName,
        position: p.position || '',
        unit: p.unit || 'Starting',
        sortOrder: p.sortOrder ?? index,
        instructions: p.instructions || '',
      })),
    });
    setShowLineupForm(true);
  };

  const handleSavePlan = async () => {
    setError('');
    if (!planForm.title.trim() || !planForm.content.trim()) {
      setError('Please add a title and plan content');
      return;
    }

    setSaving(true);
    try {
      const request = {
        title: planForm.title.trim(),
        description: planForm.description.trim() || null,
        content: planForm.content.trim(),
        visibility: planForm.visibility,
      };

      if (editingPlan) {
        const updated = await updatePlan(activeClubId, activeTeamId, editingPlan.planId, request);
        setViewingPlan(updated);
      } else {
        await createPlan(activeClubId, activeTeamId, request);
      }

      setShowPlanForm(false);
      setEditingPlan(null);
      await loadData();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to save plan');
    } finally {
      setSaving(false);
    }
  };

  const handleSaveLineup = async () => {
    setError('');
    if (!lineupForm.title.trim()) {
      setError('Please add a lineup title');
      return;
    }
    if (lineupForm.players.length === 0) {
      setError('Add at least one player to the lineup');
      return;
    }

    setSaving(true);
    try {
      const request = {
        title: lineupForm.title.trim(),
        formation: lineupForm.formation.trim() || null,
        eventId: lineupForm.eventId || null,
        gameModel: lineupForm.gameModel.trim() || null,
        tacticalNotes: lineupForm.tacticalNotes.trim() || null,
        visibility: lineupForm.visibility,
        players: lineupForm.players.map((p, index) => ({
          playerUserId: p.playerUserId,
          position: p.position.trim() || 'Unassigned',
          unit: p.unit || 'Starting',
          sortOrder: index,
          instructions: p.instructions.trim() || null,
        })),
      };

      if (editingLineup) {
        const updated = await updateLineup(activeClubId, activeTeamId, editingLineup.lineupId, request);
        setViewingLineup(updated);
      } else {
        await createLineup(activeClubId, activeTeamId, request);
      }

      setShowLineupForm(false);
      setEditingLineup(null);
      await loadData();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to save lineup');
    } finally {
      setSaving(false);
    }
  };

  const handleDeletePlan = async (plan) => {
    if (!plan) return;
    setDeleting(true);
    try {
      await deletePlan(activeClubId, activeTeamId, plan.planId);
      setViewingPlan(null);
      await loadData();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to delete plan');
    } finally {
      setDeleting(false);
    }
  };

  const handleDeleteLineup = async (lineup) => {
    if (!lineup) return;
    setDeleting(true);
    try {
      await deleteLineup(activeClubId, activeTeamId, lineup.lineupId);
      setViewingLineup(null);
      await loadData();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to delete lineup');
    } finally {
      setDeleting(false);
    }
  };

  const requestDeletePlan = (plan) => setConfirmDelete({ type: 'plan', item: plan });
  const requestDeleteLineup = (lineup) => setConfirmDelete({ type: 'lineup', item: lineup });
  const closeDeleteModal = () => setConfirmDelete(null);
  const confirmDeleteAction = async () => {
    if (!confirmDelete?.item) return;
    if (confirmDelete.type === 'plan') await handleDeletePlan(confirmDelete.item);
    if (confirmDelete.type === 'lineup') await handleDeleteLineup(confirmDelete.item);
    closeDeleteModal();
  };

  const addLineupPlayer = (playerUserId) => {
    const player = players.find((p) => p.userId === playerUserId);
    if (!player || lineupForm.players.some((p) => p.playerUserId === playerUserId)) return;
    setLineupForm((form) => ({ ...form, players: [...form.players, blankLineupPlayer(player, form.players.length)] }));
  };

  const updateLineupPlayer = (index, key, value) => {
    setLineupForm((form) => ({
      ...form,
      players: form.players.map((player, i) => i === index ? { ...player, [key]: value } : player),
    }));
  };

  const removeLineupPlayer = (index) => {
    setLineupForm((form) => ({ ...form, players: form.players.filter((_, i) => i !== index) }));
  };

  if (!activeTeamId) {
    return (
      <PageTransition className="flex-1">
        <TopBar title="Plans" />
        <div className="px-4 py-8">
          <EmptyState icon={FileText} title="No team selected" subtitle="Select a team to see coaching plans and lineups" />
        </div>
      </PageTransition>
    );
  }

  return (
    <PageTransition className="flex-1">
      <TopBar title="Plans" />
      <div className="px-4 md:px-6 lg:px-8 pb-24 lg:pb-8 max-w-7xl mx-auto w-full">
        <div className="flex items-center justify-between gap-3 mb-3">
          <div className="min-w-0">
            <p className={`text-body-sm ${isDark ? 'text-white/50' : 'text-gray-500'}`}>{selectedTeam?.teamName || 'Selected team'}</p>
          </div>
          <div className="flex items-center gap-2">
            <button onClick={() => setTab('Plans')} className={`px-3 py-2 rounded-pill text-sm font-semibold ${tab === 'Plans' ? 'bg-primary text-white' : isDark ? 'bg-surface-dark text-white/70' : 'bg-white text-gray-600 shadow-sm'}`}>Plans</button>
            <button onClick={() => setTab('Lineups')} className={`px-3 py-2 rounded-pill text-sm font-semibold ${tab === 'Lineups' ? 'bg-primary text-white' : isDark ? 'bg-surface-dark text-white/70' : 'bg-white text-gray-600 shadow-sm'}`}>Lineups</button>
          </div>
        </div>

        {canCreate && (
          <div className="flex justify-end mb-3">
            <button
              onClick={tab === 'Plans' ? openCreatePlan : openCreateLineup}
              className="flex items-center gap-2 px-4 py-2.5 rounded-card bg-primary text-white text-sm font-semibold hover:bg-primary-dark transition-colors"
            >
              <Plus size={16} />{tab === 'Plans' ? 'Create Plan' : 'Create Lineup'}
            </button>
          </div>
        )}

        {loading && <div className="flex justify-center py-8"><LoadingSpinner /></div>}
        {!loading && tab === 'Plans' && <PlanList isDark={isDark} plans={plans} canEditPlan={canEditPlan} onView={setViewingPlan} />}
        {!loading && tab === 'Lineups' && <LineupList isDark={isDark} lineups={lineups} canEditLineup={canEditLineup} onView={setViewingLineup} />}
      </div>

      <Modal isOpen={showPlanForm} onClose={() => setShowPlanForm(false)} title={editingPlan ? 'Edit Plan' : 'Create Plan'}>
        <PlanForm isDark={isDark} error={error} form={planForm} setForm={setPlanForm} saving={saving} onSave={handleSavePlan} editing={!!editingPlan} />
      </Modal>

      <Modal isOpen={showLineupForm} onClose={() => setShowLineupForm(false)} title={editingLineup ? 'Edit Lineup' : 'Create Lineup'}>
        <LineupForm
          isDark={isDark}
          error={error}
          form={lineupForm}
          setForm={setLineupForm}
          players={players}
          eventOptions={eventOptions}
          eventValues={eventValues}
          saving={saving}
          onSave={handleSaveLineup}
          addPlayer={addLineupPlayer}
          updatePlayer={updateLineupPlayer}
          removePlayer={removeLineupPlayer}
          editing={!!editingLineup}
        />
      </Modal>

      <Modal isOpen={!!viewingPlan} onClose={() => setViewingPlan(null)} title={viewingPlan?.title || 'Plan'}>
        {viewingPlan && (
          <PlanDetail
            isDark={isDark}
            plan={viewingPlan}
            error={error}
            canEdit={canEditPlan(viewingPlan)}
            deleting={deleting}
            onEdit={() => openEditPlan(viewingPlan)}
            onDelete={() => requestDeletePlan(viewingPlan)}
            deleteLabel="Delete Plan"
          />
        )}
      </Modal>

      <Modal isOpen={!!viewingLineup} onClose={() => setViewingLineup(null)} title={viewingLineup?.title || 'Lineup'}>
        {viewingLineup && (
          <LineupDetail
            isDark={isDark}
            lineup={viewingLineup}
            error={error}
            canEdit={canEditLineup(viewingLineup)}
            deleting={deleting}
            onEdit={() => openEditLineup(viewingLineup)}
            onDelete={() => requestDeleteLineup(viewingLineup)}
            deleteLabel="Delete Lineup"
          />
        )}
      </Modal>

      <Modal isOpen={!!confirmDelete?.item} onClose={closeDeleteModal} title="Confirm deletion">
        <div className="flex flex-col gap-3">
          <p className={`text-sm ${isDark ? 'text-white/70' : 'text-gray-600'}`}>
            Delete this {confirmDelete?.type === 'plan' ? 'plan' : 'lineup'}? This action cannot be undone.
          </p>
          <div className="grid grid-cols-2 gap-2">
            <button
              onClick={closeDeleteModal}
              className={`py-2.5 rounded-card text-sm font-semibold ${isDark ? 'bg-white/10 text-white' : 'bg-gray-100 text-gray-700'}`}
            >
              Cancel
            </button>
            <button
              onClick={confirmDeleteAction}
              disabled={deleting}
              className="py-2.5 rounded-card text-sm font-semibold bg-red-500 text-white hover:bg-red-600 transition-colors disabled:opacity-60"
            >
              {deleting ? 'Deleting...' : 'Delete'}
            </button>
          </div>
        </div>
      </Modal>
    </PageTransition>
  );
}

function blankLineupPlayer(player, index) {
  return {
    playerUserId: player.userId,
    playerName: player.name,
    position: '',
    unit: index < 11 ? 'Starting' : 'Bench',
    sortOrder: index,
    instructions: '',
  };
}

function VisibilityBadge({ visibility }) {
  const badge = VIS_BADGE[visibility] || VIS_BADGE.Draft;
  const BadgeIcon = badge.icon;
  return <span className={`flex items-center gap-1 text-xs px-2 py-1 rounded-pill ${badge.color}`}><BadgeIcon size={12} />{badge.label}</span>;
}

function PlanList({ isDark, plans, canEditPlan, onView }) {
  if (plans.length === 0) return <EmptyState icon={FileText} title="No plans yet" subtitle="Coaching plans will appear here when created" />;
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mt-2">
      {plans.map((plan) => (
        <button key={plan.planId} onClick={() => onView(plan)} className={`p-4 rounded-card shadow-sm text-left transition-colors ${isDark ? 'bg-surface-dark hover:bg-white/5' : 'bg-white hover:bg-gray-50'}`}>
          <div className="flex items-start justify-between gap-2">
            <h3 className={`font-semibold text-body ${isDark ? 'text-white' : 'text-black'}`}>{plan.title}</h3>
            <VisibilityBadge visibility={plan.visibility} />
          </div>
          {plan.description && <p className={`text-body-sm mt-1 ${isDark ? 'text-white/50' : 'text-gray-500'}`}>{plan.description}</p>}
          <p className={`text-xs mt-2 line-clamp-3 ${isDark ? 'text-white/60' : 'text-gray-600'}`}>{plan.content}</p>
          <CardFooter isDark={isDark} creatorName={plan.creatorName} updatedAt={plan.updatedAt || plan.createdAt} editable={canEditPlan(plan)} />
        </button>
      ))}
    </div>
  );
}

function LineupList({ isDark, lineups, canEditLineup, onView }) {
  if (lineups.length === 0) return <EmptyState icon={ClipboardList} title="No lineups yet" subtitle="Coach-created lineups will appear here when published or drafted" />;
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mt-2">
      {lineups.map((lineup) => (
        <button key={lineup.lineupId} onClick={() => onView(lineup)} className={`p-4 rounded-card shadow-sm text-left transition-colors ${isDark ? 'bg-surface-dark hover:bg-white/5' : 'bg-white hover:bg-gray-50'}`}>
          <div className="flex items-start justify-between gap-2">
            <div>
              <h3 className={`font-semibold text-body ${isDark ? 'text-white' : 'text-black'}`}>{lineup.title}</h3>
              <p className={`text-xs mt-1 ${isDark ? 'text-white/50' : 'text-gray-500'}`}>{lineup.formation || 'No formation'} - {lineup.players?.length || 0} players</p>
            </div>
            <VisibilityBadge visibility={lineup.visibility} />
          </div>
          {lineup.eventTitle && <p className={`text-xs mt-2 ${isDark ? 'text-white/50' : 'text-gray-500'}`}>{lineup.eventTitle} - {new Date(lineup.eventStartAt).toLocaleDateString()}</p>}
          <div className="flex flex-wrap gap-1.5 mt-3">
            {(lineup.players || []).slice(0, 6).map((player) => (
              <span key={player.lineupPlayerId} className={`px-2 py-1 rounded-pill text-xs ${isDark ? 'bg-white/10 text-white/70' : 'bg-gray-100 text-gray-600'}`}>{player.position}: {player.playerName}</span>
            ))}
          </div>
          <CardFooter isDark={isDark} creatorName={lineup.creatorName} updatedAt={lineup.updatedAt || lineup.createdAt} editable={canEditLineup(lineup)} />
        </button>
      ))}
    </div>
  );
}

function CardFooter({ isDark, creatorName, updatedAt, editable }) {
  return (
    <div className="flex items-center justify-between gap-2 mt-3">
      <p className={`text-xs ${isDark ? 'text-white/30' : 'text-gray-400'}`}>By {creatorName} - {new Date(updatedAt).toLocaleDateString()}</p>
      {editable && <span className={`inline-flex items-center gap-1 text-xs ${isDark ? 'text-white/50' : 'text-gray-500'}`}><Pencil size={12} />Edit</span>}
    </div>
  );
}

function PlanForm({ isDark, error, form, setForm, saving, onSave, editing }) {
  return (
    <div className="flex flex-col gap-3">
      {error && <div className="p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{error}</div>}
      <FormInput label="Title *" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} id="input-plan-title" />
      <FormInput label="Description" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} id="input-plan-description" />
      <div>
        <label className={`block text-sm font-medium mb-1 ${isDark ? 'text-white/70' : 'text-gray-600'}`}>Content *</label>
        <textarea value={form.content} onChange={(e) => setForm({ ...form, content: e.target.value })} rows={7} className={`w-full px-4 py-3 rounded-card border-2 text-sm outline-none transition-colors resize-none ${isDark ? 'bg-surface-dark text-white border-accent/50 focus:border-accent placeholder:text-white/30' : 'bg-white text-black border-accent/50 focus:border-accent placeholder:text-gray-400'}`} id="input-plan-content" />
      </div>
      <SelectField label="Visibility" value={form.visibility} onChange={(visibility) => setForm({ ...form, visibility })} options={VISIBILITY_LABELS} optionValues={VISIBILITIES} id="select-plan-visibility" />
      <button onClick={onSave} disabled={saving} className="w-full py-3 rounded-card bg-primary text-white font-semibold hover:bg-primary-dark transition-colors disabled:opacity-60" id="btn-save-plan">
        {saving ? 'Saving...' : editing ? 'Save Changes' : 'Create Plan'}
      </button>
    </div>
  );
}

function LineupForm({ isDark, error, form, setForm, players, eventOptions, eventValues, saving, onSave, addPlayer, updatePlayer, removePlayer, editing }) {
  const availablePlayers = players.filter((p) => !form.players.some((row) => row.playerUserId === p.userId));
  return (
    <div className="flex flex-col gap-3">
      {error && <div className="p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{error}</div>}
      <FormInput label="Title *" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} id="input-lineup-title" />
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        <FormInput label="Formation" value={form.formation} onChange={(e) => setForm({ ...form, formation: e.target.value })} id="input-lineup-formation" />
        <SelectField label="Linked Event" value={form.eventId} onChange={(eventId) => setForm({ ...form, eventId })} options={eventOptions} optionValues={eventValues} id="select-lineup-event" />
      </div>
      <SelectField label="Visibility" value={form.visibility} onChange={(visibility) => setForm({ ...form, visibility })} options={VISIBILITY_LABELS} optionValues={VISIBILITIES} id="select-lineup-visibility" />
      <Textarea isDark={isDark} label="Game Model" value={form.gameModel} onChange={(value) => setForm({ ...form, gameModel: value })} rows={3} />
      <Textarea isDark={isDark} label="Tactical Notes" value={form.tacticalNotes} onChange={(value) => setForm({ ...form, tacticalNotes: value })} rows={3} />

      {availablePlayers.length > 0 && (
        <SelectField label="Add Player" value="" onChange={addPlayer} options={availablePlayers.map((p) => p.name)} optionValues={availablePlayers.map((p) => p.userId)} id="select-add-lineup-player" />
      )}

      <div className={`rounded-card overflow-hidden border ${isDark ? 'border-white/10' : 'border-gray-100'}`}>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className={isDark ? 'text-white/50' : 'text-gray-500'}>
              <tr className={isDark ? 'border-b border-white/10' : 'border-b border-gray-100'}>
                <th className="text-left p-3 font-medium min-w-[150px]">Player</th>
                <th className="text-left p-3 font-medium min-w-[110px]">Position</th>
                <th className="text-left p-3 font-medium min-w-[110px]">Unit</th>
                <th className="text-left p-3 font-medium min-w-[180px]">Instructions</th>
                <th className="p-3" />
              </tr>
            </thead>
            <tbody>
              {form.players.map((player, index) => (
                <tr key={player.playerUserId} className={isDark ? 'border-b border-white/5' : 'border-b border-gray-50'}>
                  <td className={`p-3 font-semibold ${isDark ? 'text-white' : 'text-black'}`}>{player.playerName}</td>
                  <td className="p-2"><InlineInput isDark={isDark} value={player.position} onChange={(value) => updatePlayer(index, 'position', value)} placeholder="ST" /></td>
                  <td className="p-2">
                    <select value={player.unit} onChange={(e) => updatePlayer(index, 'unit', e.target.value)} className={`w-28 px-2 py-2 rounded-card border text-sm outline-none ${isDark ? 'bg-surface-darkest text-white border-white/10' : 'bg-white text-black border-gray-200'}`}>
                      {LINEUP_UNITS.map((unit) => <option key={unit} value={unit}>{unit}</option>)}
                    </select>
                  </td>
                  <td className="p-2"><InlineInput isDark={isDark} value={player.instructions} onChange={(value) => updatePlayer(index, 'instructions', value)} placeholder="Press trigger" wide /></td>
                  <td className="p-2"><button onClick={() => removePlayer(index)} className="p-2 rounded-card bg-red-500/10 text-red-500"><Trash2 size={15} /></button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <button onClick={onSave} disabled={saving} className="w-full py-3 rounded-card bg-primary text-white font-semibold hover:bg-primary-dark transition-colors disabled:opacity-60" id="btn-save-lineup">
        {saving ? 'Saving...' : editing ? 'Save Lineup' : 'Create Lineup'}
      </button>
    </div>
  );
}

function InlineInput({ isDark, value, onChange, placeholder, wide }) {
  return (
    <input value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} className={`${wide ? 'w-44' : 'w-24'} px-2 py-2 rounded-card border text-sm outline-none ${isDark ? 'bg-surface-darkest text-white border-white/10 placeholder:text-white/30' : 'bg-white text-black border-gray-200 placeholder:text-gray-400'}`} />
  );
}

function Textarea({ isDark, label, value, onChange, rows }) {
  return (
    <textarea value={value} onChange={(e) => onChange(e.target.value)} rows={rows} placeholder={label} className={`w-full px-4 py-3 rounded-card border-2 text-sm outline-none transition-colors resize-none ${isDark ? 'bg-surface-dark text-white border-accent/50 focus:border-accent placeholder:text-white/30' : 'bg-white text-black border-accent/50 focus:border-accent placeholder:text-gray-400'}`} />
  );
}

function PlanDetail({ isDark, plan, error, canEdit, deleting, onEdit, onDelete, deleteLabel }) {
  return (
    <div className="flex flex-col gap-3">
      {error && <div className="p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{error}</div>}
      <div className="flex items-center justify-between gap-2"><VisibilityBadge visibility={plan.visibility} /><span className={`text-xs ${isDark ? 'text-white/40' : 'text-gray-400'}`}>By {plan.creatorName}</span></div>
      {plan.description && <p className={`text-sm ${isDark ? 'text-white/60' : 'text-gray-600'}`}>{plan.description}</p>}
      <div className={`p-3 rounded-card text-sm whitespace-pre-wrap ${isDark ? 'bg-surface-darkest text-white/80' : 'bg-gray-50 text-gray-700'}`}>{plan.content}</div>
      {canEdit && <ActionButtons deleting={deleting} onEdit={onEdit} onDelete={onDelete} deleteLabel={deleteLabel} />}
    </div>
  );
}

function LineupDetail({ isDark, lineup, error, canEdit, deleting, onEdit, onDelete, deleteLabel }) {
  return (
    <div className="flex flex-col gap-3">
      {error && <div className="p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm">{error}</div>}
      <div className="flex items-center justify-between gap-2"><VisibilityBadge visibility={lineup.visibility} /><span className={`text-xs ${isDark ? 'text-white/40' : 'text-gray-400'}`}>By {lineup.creatorName}</span></div>
      <div className="grid grid-cols-2 gap-2">
        <MiniMetric isDark={isDark} label="Formation" value={lineup.formation || '-'} />
        <MiniMetric isDark={isDark} label="Players" value={lineup.players?.length || 0} />
      </div>
      {lineup.eventTitle && <p className={`text-sm ${isDark ? 'text-white/50' : 'text-gray-500'}`}>{lineup.eventTitle} - {new Date(lineup.eventStartAt).toLocaleDateString()}</p>}
      {lineup.gameModel && <DetailBlock isDark={isDark} title="Game Model" text={lineup.gameModel} />}
      {lineup.tacticalNotes && <DetailBlock isDark={isDark} title="Tactical Notes" text={lineup.tacticalNotes} />}
      <div className="space-y-2">
        {(lineup.players || []).map((player) => (
          <div key={player.lineupPlayerId} className={`p-3 rounded-card ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
            <div className="flex items-center justify-between gap-2">
              <p className={`font-semibold text-sm ${isDark ? 'text-white' : 'text-black'}`}>{player.position} - {player.playerName}</p>
              <span className="text-xs px-2 py-1 rounded-pill bg-primary/10 text-primary">{player.unit}</span>
            </div>
            {player.instructions && <p className={`text-xs mt-1 ${isDark ? 'text-white/50' : 'text-gray-500'}`}>{player.instructions}</p>}
          </div>
        ))}
      </div>
      {canEdit && <ActionButtons deleting={deleting} onEdit={onEdit} onDelete={onDelete} deleteLabel={deleteLabel} />}
    </div>
  );
}

function DetailBlock({ isDark, title, text }) {
  return (
    <div className={`p-3 rounded-card ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
      <p className={`text-xs font-semibold mb-1 ${isDark ? 'text-white/40' : 'text-gray-500'}`}>{title}</p>
      <p className={`text-sm whitespace-pre-wrap ${isDark ? 'text-white/80' : 'text-gray-700'}`}>{text}</p>
    </div>
  );
}

function MiniMetric({ isDark, label, value }) {
  return (
    <div className={`p-3 rounded-card ${isDark ? 'bg-surface-darkest' : 'bg-gray-50'}`}>
      <p className={`text-xs ${isDark ? 'text-white/40' : 'text-gray-500'}`}>{label}</p>
      <p className={`text-sm font-bold mt-1 ${isDark ? 'text-white' : 'text-black'}`}>{value}</p>
    </div>
  );
}

function ActionButtons({ deleting, onEdit, onDelete, deleteLabel }) {
  return (
    <div className="grid grid-cols-2 gap-2 pt-1">
      <button onClick={onEdit} className="flex items-center justify-center gap-2 py-2.5 rounded-card bg-primary text-white text-sm font-semibold hover:bg-primary-dark transition-colors"><Pencil size={15} />Edit</button>
      <button onClick={onDelete} disabled={deleting} className="flex items-center justify-center gap-2 py-2.5 rounded-card bg-red-500 text-white text-sm font-semibold hover:bg-red-600 transition-colors disabled:opacity-60"><Trash2 size={15} />{deleting ? 'Deleting...' : deleteLabel}</button>
    </div>
  );
}
