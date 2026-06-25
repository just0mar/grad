import 'dart:convert';

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'dart:math';

import 'package:eqq/addplans/AddPlansView.dart';
import '../core/app_background.dart';
import 'package:flutter/material.dart';
import '../services/file_cache_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../appbar/CustomAppBar.dart';
import '../core/app_localizations.dart';
import '../core/document_manager.dart';
import '../core/app_transitions.dart';
import '../models/api_models.dart';
import '../services/plan_service.dart';
import '../team/team_bloc.dart';
import '../core/app_localizations.dart';
import 'plans_bloc.dart';

const _planOffensiveColor = Color(0xFFFF6D00);
const _planDefensiveColor = Color(0xFF1565C0);

Color _planAccentColor(String category) => category.toLowerCase() == 'defensive'
    ? _planDefensiveColor
    : _planOffensiveColor;

class PlansView extends StatefulWidget {
  const PlansView({super.key});

  @override
  State<PlansView> createState() => _PlansViewState();
}

/// App-styled 3-dots menu offering Edit / Delete for a plan.
class _PlanActionsMenu extends StatelessWidget {
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlanActionsMenu({
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: dialogDark ? const Color(0xFF10251C) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            AppLocalizations.of(ctx).plansDeletePlanTitle,
            style: TextStyle(
              fontFamily: 'SFPro',
              fontWeight: FontWeight.w800,
              color: dialogDark ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            AppLocalizations.of(ctx).plansDeletePlanDesc,
            style: TextStyle(
              fontFamily: 'SFPro',
              color: dialogDark ? Colors.white70 : Colors.black54,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                AppLocalizations.of(ctx).cancel,
                style: const TextStyle(
                  fontFamily: 'SFPro',
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                AppLocalizations.of(ctx).plansDelete,
                style: const TextStyle(
                  fontFamily: 'SFPro',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed == true) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: t.plansOptions,
      icon: Icon(
        Icons.more_vert_rounded,
        color: isDark ? Colors.white70 : Colors.black54,
      ),
      color: isDark ? const Color(0xFF143026) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
        } else if (value == 'delete') {
          _confirmDelete(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit_rounded, size: 20, color: Colors.green),
              const SizedBox(width: 12),
              Text(
                t.plansEdit,
                style: TextStyle(
                  fontFamily: 'SFPro',
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_rounded, size: 20, color: Colors.redAccent),
              const SizedBox(width: 12),
              Text(
                t.plansDelete,
                style: const TextStyle(
                  fontFamily: 'SFPro',
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlansViewState extends State<PlansView> {
  @override
  Widget build(BuildContext context) {
    final teamState = context.watch<TeamBloc>().state;
    final selected = teamState.availableTeams
        .where((team) => team.id == teamState.selectedTeamId)
        .toList();
    final clubId = selected.isEmpty ? null : selected.first.clubId;
    final teamId = teamState.selectedTeamId;

    return BlocProvider(
      key: ValueKey('$clubId-$teamId'),
      create: (_) {
        final bloc = PlansBloc();
        if ((clubId ?? '').isNotEmpty && teamId.isNotEmpty) {
          bloc.add(LoadPlans(clubId: clubId!, teamId: teamId));
        }
        return bloc;
      },
      child: const _PlansContent(),
    );
  }
}

class _PlansContent extends StatelessWidget {
  const _PlansContent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final teamRole = context.select(
      (TeamBloc bloc) => bloc.state.userRoleInSelectedTeam,
    );
    final canManagePlans = _roleKey(teamRole) == 'coach';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlocConsumer<PlansBloc, PlansState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () async {
              final clubId = state.clubId;
              final teamId = state.teamId;
              if (clubId != null && teamId != null) {
                context.read<PlansBloc>().add(
                  LoadPlans(clubId: clubId, teamId: teamId),
                );
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (canManagePlans) _buildAddPlanButton(context),
                const SizedBox(height: 20),
                if (state.isLoading && state.plans.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else if (state.plans.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text(
                        canManagePlans
                            ? AppLocalizations.of(context).plansNoPlansAdd
                            : AppLocalizations.of(context).plansNoPlans,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  )
                else
                  ...state.plans.asMap().entries.map((entry) {
                    final i = entry.key;
                    final plan = entry.value;
                    final bloc = context.read<PlansBloc>();
                    return StaggeredListItem(
                      index: i,
                      child: _PlanCard(
                        key: ValueKey(plan.planId),
                        plan: plan,
                        textColor: textColor,
                        isDark: isDark,
                        canManage: canManagePlans,
                        onTap: () => _openPlanDetail(context, plan),
                        onEdit: () => _openPlanEditor(context, bloc, plan: plan),
                        onDelete: () => _deletePlan(bloc, plan),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddPlanButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _openPlanEditor(context, context.read<PlansBloc>()),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          AppLocalizations.of(context).plansAddPlanBtn,
          style: const TextStyle(fontFamily: 'SFPro', fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  Future<void> _openPlanEditor(
    BuildContext context,
    PlansBloc bloc, {
    PlanDto? plan,
  }) async {
    final result = await Navigator.push(
      context,
      AppPageRoute(
        child: AddPlanScreen(
          isEditing: plan != null,
          initialTitle: plan?.title,
          initialDescription: plan?.description,
          initialVisibility: plan?.visibility,
          initialCategory: plan?.category,
          initialTacticalBoardData: plan?.tacticalBoardData,
          initialDocuments: plan?.documents ?? const [],
        ),
      ),
    );
    if (result is! Map<String, dynamic>) return;
    final attachments =
        (result['attachments'] as List?)?.cast<PlatformFile>() ?? [];
    final discardedDocumentIds =
        (result['discardedDocumentIds'] as List?)?.cast<String>() ?? [];
    final eventCategory = result['category']?.toString() ?? 'Offensive';
    final tacticalBoardData = result['tacticalBoardData']?.toString();
    if (plan == null) {
      bloc.add(
        CreatePlan(
          title: result['title']?.toString() ?? '',
          description: result['description']?.toString() ?? '',
          visibility: result['visibility']?.toString() ?? 'Draft',
          category: eventCategory,
          attachments: attachments,
          tacticalBoardData: tacticalBoardData,
        ),
      );
    } else {
      bloc.add(
        UpdatePlan(
          planId: plan.planId,
          title: result['title']?.toString() ?? '',
          description: result['description']?.toString() ?? '',
          visibility: result['visibility']?.toString() ?? 'Draft',
          category: eventCategory,
          attachments: attachments,
          discardedDocumentIds: discardedDocumentIds,
          tacticalBoardData: tacticalBoardData,
        ),
      );
    }
  }

  void _deletePlan(PlansBloc bloc, PlanDto plan) {
    bloc.add(DeletePlan(plan.planId));
  }

  void _openPlanDetail(BuildContext context, PlanDto plan) {
    final teamRole = context.read<TeamBloc>().state.userRoleInSelectedTeam;
    final canManage = _roleKey(teamRole) == 'coach';
    final bloc = context.read<PlansBloc>();
    Navigator.push(
      context,
      AppPageRoute(
        child: PlanDetailView(
          plan: plan,
          canManage: canManage,
          onEdit: (ctx) => _openPlanEditor(ctx, bloc, plan: plan),
          onDelete: () => _deletePlan(bloc, plan),
        ),
      ),
    );
  }

  String _roleKey(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Plan Card with category colour rail + document count badge
// ═══════════════════════════════════════════════════════════════════════════════

class PlanDetailView extends StatelessWidget {
  final PlanDto plan;
  final bool canManage;
  final Future<void> Function(BuildContext context)? onEdit;
  final VoidCallback? onDelete;

  const PlanDetailView({
    super.key,
    required this.plan,
    this.canManage = false,
    this.onEdit,
    this.onDelete,
  });

  Color get _accent => _planAccentColor(plan.category);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final muted = isDark ? Colors.white60 : Colors.black54;
    final bgColors = isDark
        ? [const Color(0xFF0A1F15), const Color(0xFF020806)]
        : [Colors.green, Colors.white];
    final preview = _PlanBoardPreviewData.fromJson(plan.tacticalBoardData);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: AppLocalizations.of(context).plansPlanTitle,
        onBack: () => Navigator.pop(context),
        showTeamSwitcher: false,
      ),
      body: AppBackground(
        child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              children: [
                _PlanDetailCard(
                  plan: plan,
                  preview: preview,
                  accent: _accent,
                  textColor: textColor,
                  muted: muted,
                  isDark: isDark,
                  canManage: canManage,
                  onEdit: onEdit == null
                      ? null
                      : () async {
                          await onEdit!(context);
                          if (context.mounted) Navigator.pop(context);
                        },
                  onDelete: onDelete == null
                      ? null
                      : () {
                          onDelete!();
                          Navigator.pop(context);
                        },
                ),
              ],
            ),
          ),
        ),
      );
  }
}

class _PlanDetailCard extends StatelessWidget {
  final PlanDto plan;
  final _PlanBoardPreviewData preview;
  final Color accent;
  final Color textColor;
  final Color muted;
  final bool isDark;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _PlanDetailCard({
    required this.plan,
    required this.preview,
    required this.accent,
    required this.textColor,
    required this.muted,
    required this.isDark,
    this.canManage = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF10251C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 18,
            child: Container(
              width: 5,
              height: 76,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(8),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: accent.withValues(alpha: 0.14),
                      child: Icon(
                        plan.category.toLowerCase() == 'defensive'
                            ? Icons.shield_rounded
                            : Icons.sports_basketball_rounded,
                        color: accent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.title,
                            style: TextStyle(
                              color: textColor,
                              fontFamily: 'SFPro',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppLocalizations.of(context).plansCreatedBy,
                            style: TextStyle(
                              color: muted.withValues(alpha: 0.8),
                              fontFamily: 'SFPro',
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            plan.creatorName.isEmpty ? AppLocalizations.of(context).plansTeamStaff : plan.creatorName,
                            style: TextStyle(
                              color: textColor,
                              fontFamily: 'SFPro',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CategoryBadge(label: plan.category, color: accent),
                    if (canManage && onEdit != null && onDelete != null)
                      _PlanActionsMenu(
                        isDark: isDark,
                        onEdit: onEdit!,
                        onDelete: onDelete!,
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 0.72,
                    child: _PlanBoardPreview(
                      data: preview,
                      isDark: isDark,
                      accent: accent,
                    ),
                  ),
                ),
                if (plan.documents.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _PlanDocumentsSection(
                    documents: plan.documents,
                    planId: plan.planId,
                    accent: accent,
                    isDark: isDark,
                    textColor: textColor,
                    muted: muted,
                  ),
                ],
                const SizedBox(height: 22),
                Text(
                  plan.description?.isNotEmpty == true
                      ? plan.description!
                      : AppLocalizations.of(context).plansNoDesc,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.84),
                    fontFamily: 'SFPro',
                    fontSize: 16,
                    height: 1.34,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanDto plan;
  final Color textColor;
  final bool isDark;
  final VoidCallback onTap;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlanCard({
    super.key,
    required this.plan,
    required this.textColor,
    required this.isDark,
    required this.onTap,
    this.canManage = false,
    required this.onEdit,
    required this.onDelete,
  });

  static const _offensiveColor = Color(0xFFFF6D00);
  static const _defensiveColor = Color(0xFF1565C0);

  Color get _railColor => plan.category.toLowerCase() == 'defensive'
      ? _defensiveColor
      : _offensiveColor;

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF10251C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.07);
    final preview = _PlanBoardPreviewData.fromJson(plan.tacticalBoardData);

    return AnimatedPressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 18,
              child: Container(
                width: 5,
                height: 76,
                decoration: BoxDecoration(
                  color: _railColor,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: _railColor.withValues(alpha: 0.14),
                        child: Icon(
                          plan.category.toLowerCase() == 'defensive'
                              ? Icons.shield_rounded
                              : Icons.sports_basketball_rounded,
                          color: _railColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                                fontFamily: 'SFPro',
                                height: 1.28,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              AppLocalizations.of(context).plansCreatedBy,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'SFPro',
                                height: 1.2,
                              ),
                            ),
                            Text(
                              plan.creatorName.isEmpty ? AppLocalizations.of(context).plansTeamStaff : plan.creatorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'SFPro',
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _CategoryBadge(label: plan.category, color: _railColor),
                      if (canManage)
                        _PlanActionsMenu(
                          isDark: isDark,
                          onEdit: onEdit,
                          onDelete: onDelete,
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 300,
                          height: 300 / 0.72,
                          child: _PlanBoardPreview(
                            data: preview,
                            isDark: isDark,
                            accent: _railColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (plan.documents.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _PlanDocumentsSection(
                      documents: plan.documents,
                      planId: plan.planId,
                      accent: _railColor,
                      isDark: isDark,
                      textColor: textColor,
                      muted: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category badge ──────────────────────────────────────────────────────────

class _PlanBoardPreview extends StatelessWidget {
  final _PlanBoardPreviewData data;
  final bool isDark;
  final Color accent;

  const _PlanBoardPreview({
    required this.data,
    required this.isDark,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PlanBoardPreviewPainter(
        data: data,
        isDark: isDark,
        accent: accent,
        noTacticsLabel: AppLocalizations.of(context).plansNoTactics,
      ),
    );
  }
}

class _PlanBoardPreviewData {
  final List<_PlanPreviewPlayer> players;
  final List<_PlanPreviewArrow> arrows;

  const _PlanBoardPreviewData({required this.players, required this.arrows});

  factory _PlanBoardPreviewData.fromJson(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const _PlanBoardPreviewData(players: [], arrows: []);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const _PlanBoardPreviewData(players: [], arrows: []);
      }
      final data = Map<String, dynamic>.from(decoded);
      final players =
          (data['players'] as List?)
              ?.whereType<Map>()
              .map((item) {
                final player = Map<String, dynamic>.from(item);
                final label = player['label']?.toString();
                final x = (player['x'] as num?)?.toDouble();
                final y = (player['y'] as num?)?.toDouble();
                final isHome = player['isHome'] as bool? ?? true;
                if (label == null || x == null || y == null) return null;
                return _PlanPreviewPlayer(
                  label: label,
                  x: x,
                  y: y,
                  isHome: isHome,
                );
              })
              .whereType<_PlanPreviewPlayer>()
              .toList() ??
          const <_PlanPreviewPlayer>[];
      final arrows =
          (data['arrows'] as List?)
              ?.whereType<Map>()
              .map((item) {
                final arrow = Map<String, dynamic>.from(item);
                final startX = (arrow['startX'] as num?)?.toDouble();
                final startY = (arrow['startY'] as num?)?.toDouble();
                final endX = (arrow['endX'] as num?)?.toDouble();
                final endY = (arrow['endY'] as num?)?.toDouble();
                if (startX == null ||
                    startY == null ||
                    endX == null ||
                    endY == null) {
                  return null;
                }
                final points =
                    (arrow['points'] as List?)
                        ?.whereType<Map>()
                        .map((item) {
                          final point = Map<String, dynamic>.from(item);
                          final x = (point['x'] as num?)?.toDouble();
                          final y = (point['y'] as num?)?.toDouble();
                          if (x == null || y == null) return null;
                          return Offset(x, y);
                        })
                        .whereType<Offset>()
                        .toList() ??
                    <Offset>[];
                return _PlanPreviewArrow(
                  start: Offset(startX, startY),
                  end: Offset(endX, endY),
                  points: points,
                );
              })
              .whereType<_PlanPreviewArrow>()
              .toList() ??
          const <_PlanPreviewArrow>[];
      return _PlanBoardPreviewData(players: players, arrows: arrows);
    } catch (_) {
      return const _PlanBoardPreviewData(players: [], arrows: []);
    }
  }
}

class _PlanPreviewPlayer {
  final String label;
  final double x;
  final double y;
  final bool isHome;

  const _PlanPreviewPlayer({
    required this.label,
    required this.x,
    required this.y,
    required this.isHome,
  });
}

class _PlanPreviewArrow {
  final Offset start;
  final Offset end;
  final List<Offset> points;

  const _PlanPreviewArrow({
    required this.start,
    required this.end,
    required this.points,
  });
}

class _PlanBoardPreviewPainter extends CustomPainter {
  final _PlanBoardPreviewData data;
  final bool isDark;
  final Color accent;
  final String noTacticsLabel;

  const _PlanBoardPreviewPainter({
    required this.data,
    required this.isDark,
    required this.accent,
    required this.noTacticsLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgPaint = Paint()..color = const Color(0xFFCD853F);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    final grainPaint = Paint()
      ..color = const Color(0xFFC07C3A).withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (double x = 0; x < w; x += 18) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grainPaint);
    }

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(Rect.fromLTWH(1, 1, w - 2, h - 2), linePaint..strokeWidth = 2.5);
    linePaint.strokeWidth = 2;
    canvas.drawLine(Offset(0, 1), Offset(w, 1), linePaint);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w / 2, 1), width: w * 0.36, height: w * 0.36),
      0, pi, false, linePaint,
    );

    final laneW = w * 0.40;
    final laneH = h * 0.36;
    final laneLeft = (w - laneW) / 2;
    canvas.drawRect(Rect.fromLTWH(laneLeft, h - laneH, laneW, laneH), linePaint);

    final hashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.40)
      ..strokeWidth = 1.5;
    for (int i = 1; i <= 3; i++) {
      final y = h - laneH + (laneH * i / 4);
      canvas.drawLine(Offset(laneLeft - 6, y), Offset(laneLeft, y), hashPaint);
      canvas.drawLine(Offset(laneLeft + laneW, y), Offset(laneLeft + laneW + 6, y), hashPaint);
    }

    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h - laneH), width: laneW, height: laneW * 0.55),
      linePaint,
    );

    final threePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final cornerHeight = h * 0.14;
    canvas.drawLine(Offset(w * 0.06, h), Offset(w * 0.06, h - cornerHeight), threePaint);
    canvas.drawLine(Offset(w * 0.94, h), Offset(w * 0.94, h - cornerHeight), threePaint);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w / 2, h - 8), width: w * 0.88, height: h * 1.28),
      pi, pi, false, threePaint,
    );

    final restrictedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w / 2, h - 8), width: w * 0.18, height: w * 0.18),
      pi, pi, false, restrictedPaint,
    );

    final rimY = h - 14;
    final backboardPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w / 2 - 16, rimY + 6), Offset(w / 2 + 16, rimY + 6), backboardPaint);
    canvas.drawCircle(
      Offset(w / 2, rimY - 4),
      9,
      Paint()
        ..color = const Color(0xFFFF6D00).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final arrowPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = max(2.0, min(w, h) * 0.012);
    for (final arrow in data.arrows) {
      _drawDottedArrow(canvas, size, arrow, arrowPaint);
    }

    final markerRadius = (min(w, h) * 0.045).clamp(8.0, 18.0);
    for (final player in data.players) {
      final center = Offset(player.x * w, player.y * h);
      canvas.drawCircle(
        center,
        markerRadius,
        Paint()
          ..color = player.isHome
              ? const Color(0xFF2E7D32)
              : const Color(0xFFC62828),
      );
      canvas.drawCircle(
        center,
        markerRadius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: player.label,
          style: TextStyle(
            color: Colors.white,
            fontSize: markerRadius * 0.82,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: markerRadius * 2);
      painter.paint(
        canvas,
        center - Offset(painter.width / 2, painter.height / 2),
      );
    }

    if (data.players.isEmpty && data.arrows.isEmpty) {
      final painter = TextPainter(
        text: TextSpan(
          text: noTacticsLabel,
          style: TextStyle(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.45,
            ),
            fontFamily: 'SFPro',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset((w - painter.width) / 2, (h - painter.height) / 2),
      );
    }
  }

  void _drawDottedArrow(
    Canvas canvas,
    Size size,
    _PlanPreviewArrow arrow,
    Paint paint,
  ) {
    final points = arrow.points.isNotEmpty
        ? arrow.points
        : <Offset>[arrow.start, arrow.end];
    final scaled = points
        .map((point) => Offset(point.dx * size.width, point.dy * size.height))
        .toList();

    for (int i = 0; i < scaled.length - 1; i++) {
      final a = scaled[i];
      final b = scaled[i + 1];
      final distance = (b - a).distance;
      if (distance <= 0) continue;
      final direction = (b - a) / distance;
      double walked = 0;
      const dash = 6.0;
      const gap = 5.0;
      while (walked < distance) {
        final start = a + direction * walked;
        final end = a + direction * min(walked + dash, distance);
        canvas.drawLine(start, end, paint);
        walked += dash + gap;
      }
    }

    if (scaled.length < 2) return;
    final end = scaled.last;
    final prev = scaled[scaled.length - 2];
    final vector = end - prev;
    if (vector.distance == 0) return;
    final angle = atan2(vector.dy, vector.dx);
    final head = min(size.width, size.height) * 0.035;
    final p1 = end - Offset(cos(angle - pi / 6), sin(angle - pi / 6)) * head;
    final p2 = end - Offset(cos(angle + pi / 6), sin(angle + pi / 6)) * head;
    canvas.drawLine(end, p1, paint);
    canvas.drawLine(end, p2, paint);
  }

  @override
  bool shouldRepaint(covariant _PlanBoardPreviewPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.isDark != isDark ||
        oldDelegate.accent != accent;
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _CategoryBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontFamily: 'SFPro',
        ),
      ),
    );
  }
}

// ── Documents section (cards under the tactical board) ──────────────────────

IconData _documentIcon(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  switch (ext) {
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'webp':
      return Icons.image_rounded;
    case 'doc':
    case 'docx':
      return Icons.description_rounded;
    case 'xls':
    case 'xlsx':
      return Icons.table_chart_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

String _formatDocSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _PlanDocumentsSection extends StatelessWidget {
  final List<PlanDocumentDto> documents;
  final String planId;
  final Color accent;
  final bool isDark;
  final Color textColor;
  final Color muted;

  const _PlanDocumentsSection({
    required this.documents,
    required this.planId,
    required this.accent,
    required this.isDark,
    required this.textColor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.folder_rounded, size: 18, color: accent),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context).plansDocuments,
              style: TextStyle(
                color: textColor,
                fontFamily: 'SFPro',
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${documents.length}',
                style: TextStyle(
                  color: accent,
                  fontFamily: 'SFPro',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...documents.map(
          (doc) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DocumentCard(
              doc: doc,
              planId: planId,
              accent: accent,
              isDark: isDark,
              textColor: textColor,
              muted: muted,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Document card (tap to download / preview) ───────────────────────────────

class _DocumentCard extends StatefulWidget {
  final PlanDocumentDto doc;
  final String planId;
  final Color accent;
  final bool isDark;
  final Color textColor;
  final Color muted;

  const _DocumentCard({
    required this.doc,
    required this.planId,
    required this.accent,
    required this.isDark,
    required this.textColor,
    required this.muted,
  });

  @override
  State<_DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<_DocumentCard> {
  final PlanService _planService = PlanService();
  bool _busy = false;

  Future<void> _onTap() async {
    setState(() => _busy = true);
    try {
      await DocumentManager.viewDocument(
        context,
        downloadUrl: '/plans/${widget.planId}/documents/${widget.doc.documentId}/download',
        originalFileName: widget.doc.fileName,
        contentType: widget.doc.contentType,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizeLabel = _formatDocSize(widget.doc.fileSizeBytes);
    final ext = widget.doc.fileName.split('.').last.toUpperCase();
    final subtitle = sizeLabel.isEmpty ? ext : '$ext  ·  $sizeLabel';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : _onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.black.withValues(alpha: 0.18)
                : widget.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.accent.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _documentIcon(widget.doc.fileName),
                  color: widget.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.doc.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.textColor,
                        fontFamily: 'SFPro',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: widget.muted,
                        fontFamily: 'SFPro',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (_busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.accent,
                  ),
                )
              else
                Icon(
                  Icons.open_in_new_rounded,
                  size: 20,
                  color: widget.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

