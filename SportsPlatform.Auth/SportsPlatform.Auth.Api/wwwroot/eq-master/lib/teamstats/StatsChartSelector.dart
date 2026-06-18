import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Attribute groups matching app.py's ATTRIBUTE_GROUPS
class StatsAttributeGroups {
  static const Map<String, List<String>> groups = {
    'Basic': ['pts', 'reb', 'ast', 'stl', 'blk', 'two_pts_total', 'three_pts_total', 'ft_made'],
    'Rebounds': ['or', 'dr', 'reb'],
    'Discipline': ['to', 'pf', 'fd'],
    'Impact': ['eff', 'pts'],
  };

  static const Map<String, String> labels = {
    'pts': 'Points',
    'reb': 'Rebounds',
    'ast': 'Assists',
    'stl': 'Steals',
    'blk': 'Blocks',
    'two_pts_total': '2PTS Total',
    'three_pts_total': '3PTS Total',
    'ft_made': 'FT Made',
    'or': 'Off. Rebounds',
    'dr': 'Def. Rebounds',
    'to': 'Turnovers',
    'pf': 'Personal Fouls',
    'fd': 'Fouls Drawn',
    'eff': 'Efficiency',
  };

  static const List<Color> chartColors = [
    Color(0xFF1565C0), // blue
    Color(0xFF4CAF50), // green
    Color(0xFFFF9800), // orange
    Color(0xFFE91E63), // pink
    Color(0xFF9C27B0), // purple
    Color(0xFF00BCD4), // cyan
    Color(0xFFFF5722), // deep orange
    Color(0xFF607D8B), // blue grey
  ];
}

/// Widget: Attribute group selector + chart type picker
class StatsChartSelector extends StatefulWidget {
  final String selectedGroup;
  final List<String> selectedAttributes;
  final String chartType; // "line" | "bar" | "radar"
  final String level; // "player" | "team"
  final String mode; // "per_game" | "cumulative"
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<List<String>> onAttributesChanged;
  final ValueChanged<String> onChartTypeChanged;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onModeChanged;

  const StatsChartSelector({
    super.key,
    required this.selectedGroup,
    required this.selectedAttributes,
    required this.chartType,
    required this.level,
    required this.mode,
    required this.onGroupChanged,
    required this.onAttributesChanged,
    required this.onChartTypeChanged,
    required this.onLevelChanged,
    required this.onModeChanged,
  });

  @override
  State<StatsChartSelector> createState() => _StatsChartSelectorState();
}

class _StatsChartSelectorState extends State<StatsChartSelector> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white54 : Colors.black45;
    final chipBg = isDark ? const Color(0xFF0A1F15) : Colors.grey.shade100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Level: Player / Team
        Row(
          children: [
            _chip("Player", widget.level == "player", () => widget.onLevelChanged("player"), chipBg, isDark),
            const SizedBox(width: 8),
            _chip("Team", widget.level == "team", () => widget.onLevelChanged("team"), chipBg, isDark),
            const Spacer(),
            // Chart type icons
            _iconButton(Icons.show_chart, widget.chartType == "line", () => widget.onChartTypeChanged("line"), subtitleColor),
            _iconButton(Icons.bar_chart, widget.chartType == "bar", () => widget.onChartTypeChanged("bar"), subtitleColor),
            _iconButton(Icons.radar, widget.chartType == "radar", () => widget.onChartTypeChanged("radar"), subtitleColor),
          ],
        ),
        const SizedBox(height: 8),

        // Mode: Per Game / Cumulative
        Row(
          children: [
            _chip("Per Game", widget.mode == "per_game", () => widget.onModeChanged("per_game"), chipBg, isDark),
            const SizedBox(width: 8),
            _chip("Cumulative", widget.mode == "cumulative", () => widget.onModeChanged("cumulative"), chipBg, isDark),
          ],
        ),
        const SizedBox(height: 12),

        // Attribute Group selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: StatsAttributeGroups.groups.keys.map((group) {
              final selected = widget.selectedGroup == group;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _chip(group, selected, () {
                  widget.onGroupChanged(group);
                  widget.onAttributesChanged(StatsAttributeGroups.groups[group]!);
                }, chipBg, isDark),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Attribute multi-select within group
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: (StatsAttributeGroups.groups[widget.selectedGroup] ?? []).map((attr) {
            final isSelected = widget.selectedAttributes.contains(attr);
            final label = StatsAttributeGroups.labels[attr] ?? attr;
            return FilterChip(
              label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : textColor)),
              selected: isSelected,
              selectedColor: Colors.green,
              backgroundColor: chipBg,
              onSelected: (val) {
                final updated = List<String>.from(widget.selectedAttributes);
                if (val) {
                  updated.add(attr);
                } else {
                  updated.remove(attr);
                }
                widget.onAttributesChanged(updated);
              },
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, Color chipBg, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.green : chipBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : (isDark ? Colors.white54 : Colors.black54),
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, bool selected, VoidCallback onTap, Color subtitleColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? Colors.green.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: selected ? Colors.green : subtitleColor),
      ),
    );
  }
}

/// A bar chart for comparing players on a single stat
class StatsBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> playerData;
  final String attribute;
  final bool isDark;

  const StatsBarChart({
    super.key,
    required this.playerData,
    required this.attribute,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleColor = isDark ? Colors.white54 : Colors.black45;
    final barColor = Colors.green;

    final data = playerData.take(10).toList();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final name = data[group.x.toInt()]['name'] ?? '';
                return BarTooltipItem(
                  '$name\n${rod.toY.toInt()}',
                  TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: subtitleColor),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= data.length) return const SizedBox();
                  final name = (data[idx]['name'] ?? '') as String;
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      name.length > 8 ? '${name.substring(0, 8)}..' : name,
                      style: TextStyle(fontSize: 9, color: subtitleColor),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          barGroups: data.asMap().entries.map((entry) {
            final idx = entry.key;
            final val = (entry.value[attribute] as num?)?.toDouble() ?? 0;
            return BarChartGroupData(
              x: idx,
              barRods: [
                BarChartRodData(
                  toY: val,
                  color: StatsAttributeGroups.chartColors[idx % StatsAttributeGroups.chartColors.length],
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// A radar chart for player profile overview
class StatsRadarChart extends StatelessWidget {
  final Map<String, dynamic> playerData;
  final List<String> attributes;
  final bool isDark;

  const StatsRadarChart({
    super.key,
    required this.playerData,
    required this.attributes,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;

    if (attributes.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).selectAttributes, style: TextStyle(color: textColor)));
    }

    return SizedBox(
      height: 250,
      child: RadarChart(
        RadarChartData(
          dataSets: [
            RadarDataSet(
              dataEntries: attributes.map((attr) {
                final val = (playerData[attr] as num?)?.toDouble() ?? 0;
                return RadarEntry(value: val);
              }).toList(),
              fillColor: Colors.green.withValues(alpha: 0.2),
              borderColor: Colors.green,
              borderWidth: 2,
              entryRadius: 3,
            ),
          ],
          radarShape: RadarShape.polygon,
          radarBorderData: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
          tickBorderData: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
          gridBorderData: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
          tickCount: 4,
          titlePositionPercentageOffset: 0.15,
          getTitle: (index, angle) {
            if (index >= attributes.length) return RadarChartTitle(text: '');
            final label = StatsAttributeGroups.labels[attributes[index]] ?? attributes[index];
            return RadarChartTitle(
              text: label,
              angle: 0,
            );
          },
        ),
      ),
    );
  }
}
