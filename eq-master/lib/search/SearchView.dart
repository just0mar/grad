import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../appbar/CustomAppBar.dart';
import '../core/app_background.dart';
import '../core/design_tokens.dart';
import '../core/target_navigator.dart';
import '../models/api_models.dart';
import 'search_bloc.dart';
import '../core/app_localizations.dart';

class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SearchBloc(),
      child: const _SearchViewContent(),
    );
  }
}

class _SearchViewContent extends StatefulWidget {
  const _SearchViewContent();

  @override
  State<_SearchViewContent> createState() => _SearchViewContentState();
}

class _SearchViewContentState extends State<_SearchViewContent> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<(String, String, IconData)> _filters(BuildContext context) {
    final t = AppLocalizations.of(context);
    return [
      ('All', t.searchFilterAll, Icons.apps_rounded),
      ('Teams', t.searchFilterTeams, Icons.groups_rounded),
      ('Users', t.searchFilterUsers, Icons.person_rounded),
      ('Events', t.searchFilterEvents, Icons.event_rounded),
      ('Plans', t.searchFilterPlans, Icons.assignment_rounded),
      ('Announcements', t.searchFilterAnnouncements, Icons.campaign_rounded),
      ('Stats', t.searchFilterStats, Icons.bar_chart_rounded),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showFilterSheet(BuildContext context, String selectedTab) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => BlocProvider.value(
        value: context.read<SearchBloc>(),
        child: _FilterSheet(filters: _filters(context), selectedTab: selectedTab),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(title: AppLocalizations.of(context).searchTitle, showTeamSwitcher: false),
      body: AppBackground(
        child: SafeArea(
          child: BlocBuilder<SearchBloc, SearchState>(
            builder: (context, state) {
              final activeFilter =
                  state.selectedTab != 'All' ? state.selectedTab : null;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            onChanged: (v) =>
                                context.read<SearchBloc>().add(UpdateQuery(v)),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context).searchHint,
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _FilterButton(
                          isActive: activeFilter != null,
                          activeLabel: activeFilter != null 
                              ? _filters(context).firstWhere((f) => f.$1 == activeFilter, orElse: () => ('', activeFilter, Icons.apps)).$2 
                              : null,
                          onTap: () =>
                              _showFilterSheet(context, state.selectedTab),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _ResultsList(state: state)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Filter button ──────────────────────────────────────────────────────────────

class _FilterButton extends StatelessWidget {
  final bool isActive;
  final String? activeLabel;
  final VoidCallback onTap;

  const _FilterButton({
    required this.isActive,
    required this.activeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 20,
              color: isActive
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            if (isActive && activeLabel != null) ...[
              const SizedBox(width: 5),
              Text(
                activeLabel!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Filter bottom sheet ────────────────────────────────────────────────────────

class _FilterSheet extends StatelessWidget {
  final List<(String, String, IconData)> filters;
  final String selectedTab;

  const _FilterSheet({required this.filters, required this.selectedTab});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A2A20) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context).searchFilterTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: filters.map((f) {
              final (id, label, icon) = f;
              final selected = selectedTab == id;
              return GestureDetector(
                onTap: () {
                  context.read<SearchBloc>().add(UpdateTab(id));
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: selected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Results list ───────────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  final SearchState state;

  const _ResultsList({required this.state});

  Widget build(BuildContext context) {
    if (state.query.trim().length < 2) {
      return _SearchMessage(
        icon: Icons.manage_search_rounded,
        text: AppLocalizations.of(context).searchMinChars,
      );
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return _SearchMessage(
        icon: Icons.error_outline,
        text: AppLocalizations.of(context).searchErrFailed,
      );
    }

    if (state.results.isEmpty) {
      return _SearchMessage(
        icon: Icons.search_off_rounded,
        text: AppLocalizations.of(context).searchNoResults,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemBuilder: (context, index) =>
          _SearchResultCard(result: state.results[index]),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: state.results.length,
    );
  }
}

// ── Result card ────────────────────────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  final SearchResultDto result;

  const _SearchResultCard({required this.result});

  static IconData _iconFor(String type) {
    switch (type) {
      case 'team':
        return Icons.groups_rounded;
      case 'user':
        return Icons.person_rounded;
      case 'event':
        return Icons.event_rounded;
      case 'plan':
        return Icons.assignment_rounded;
      case 'announcement':
        return Icons.campaign_rounded;
      case 'stats':
        return Icons.bar_chart_rounded;
      default:
        return Icons.search_rounded;
    }
  }

  static Color _colorFor(String type) {
    switch (type) {
      case 'team':
        return Colors.teal;
      case 'user':
        return Colors.blue;
      case 'event':
        return Colors.orange;
      case 'plan':
        return Colors.purple;
      case 'announcement':
        return Colors.amber;
      case 'stats':
        return Colors.green;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _colorFor(result.type);
    final subtitle = result.subtitle ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          openTarget(
            context: context,
            type: result.type,
            targetId: (result.targetId != null && result.targetId!.isNotEmpty)
                ? result.targetId
                : result.id,
            clubId: result.clubId,
            teamId: result.teamId,
            title: result.title,
            subtitle: result.subtitle,
            metadataJson: result.metadataJson,
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B3A2D) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_iconFor(result.type), color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _translateType(result.type, context),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white30 : Colors.black26,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _translateType(String type, BuildContext context) {
    final t = AppLocalizations.of(context);
    switch (type.toLowerCase()) {
      case 'team': return t.searchFilterTeams;
      case 'user': return t.searchFilterUsers;
      case 'event': return t.searchFilterEvents;
      case 'plan': return t.searchFilterPlans;
      case 'announcement': return t.searchFilterAnnouncements;
      case 'stats': return t.searchFilterStats;
      default: return type.toUpperCase();
    }
  }
}

// ── Empty / error message ──────────────────────────────────────────────────────

class _SearchMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SearchMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: isDark ? Colors.white54 : Colors.black38),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
        ],
      ),
    );
  }
}
