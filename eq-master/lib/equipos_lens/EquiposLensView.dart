import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../appbar/CustomAppBar.dart';
import '../core/app_background.dart';

class EquiposLensView extends StatefulWidget {
  const EquiposLensView({super.key});

  @override
  State<EquiposLensView> createState() => _EquiposLensViewState();
}

class _EquiposLensViewState extends State<EquiposLensView> {
  // ── State for Uploaded Content ──────────────────────────────────────────────
  bool _videoUploaded = false;
  bool _isUploading = false;
  bool _isAnalyzing = false;
  String _analyzingText = "Extracting frames...";
  String _uploadedCaption = "";

  String? _uploadedVideoPath; // path to the file the user picked
  List<FlSpot> _upSpeedData = [];
  List<FlSpot> _upPossessionData = [];
  int _upTotalPasses = 0;
  int _upTotalInterceptions = 0;
  int _upTotalFrames = 0;
  int _upFramesWithPossession = 0;
  String _upSelectedMetric = 'speed';

  // ── State for Static Content (Angola's Game) ──────────────────────────────
  final List<FlSpot> _staticSpeedData = const [
    FlSpot(0, 5), FlSpot(10, 8), FlSpot(20, 15), FlSpot(30, 12),
    FlSpot(40, 20), FlSpot(50, 18), FlSpot(60, 25), FlSpot(70, 22),
  ];
  final List<FlSpot> _staticPossessionData = const [
    FlSpot(0, 40), FlSpot(100, 45), FlSpot(200, 55), FlSpot(300, 50),
    FlSpot(400, 60), FlSpot(500, 65), FlSpot(600, 58), FlSpot(700, 70),
  ];
  String _staticSelectedMetric = 'speed';
  bool _extractingStaticVideo = false;

  // ── Play video using the native player ─────────────────────────────────────
  Future<void> _playStaticVideo() async {
    if (_extractingStaticVideo) return;
    setState(() => _extractingStaticVideo = true);

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/2nd_video_temp.mp4');

      if (!await tempFile.exists()) {
        // Extract the asset to a temp file (one-time)
        final byteData = await rootBundle.load('assets/2nd video.mp4');
        await tempFile.writeAsBytes(
          byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
          flush: true,
        );
      }

      final result = await OpenFilex.open(tempFile.path, type: 'video/mp4');
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open video: ${result.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing video: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _extractingStaticVideo = false);
    }
  }

  Future<void> _playUploadedVideo() async {
    if (_uploadedVideoPath == null) return;
    final result = await OpenFilex.open(_uploadedVideoPath!);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open video: ${result.message}')),
      );
    }
  }

  // ── Upload & Analyze Flow ───────────────────────────────────────────────────
  Future<void> _pickVideo() async {
    setState(() => _isUploading = true);

    try {
      FilePickerResult? result =
          await FilePicker.platform.pickFiles(type: FileType.video);

      if (result != null && result.files.single.path != null) {
        // 1. Ask for Caption
        String? caption = await _showCaptionDialog();
        if (caption == null || caption.isEmpty) {
          setState(() => _isUploading = false);
          return; // Cancelled
        }

        setState(() {
          _uploadedCaption = caption.toUpperCase();
          _isUploading = false;
          _isAnalyzing = true;
        });

        // 2. Play "Analyzing" Animation
        await _playAnalyzingAnimation();

        // 3. Load Data + store the video path
        _uploadedVideoPath = result.files.single.path!;

        await Future.wait([
          _loadSpeedData(),
          _loadPossessionData(),
          _loadPassesData(),
          _loadInterceptionsData(),
          _loadSummary(),
        ]);

        // 4. Finish
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            _videoUploaded = true;
          });
        }
      } else {
        if (mounted) setState(() => _isUploading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<String?> _showCaptionDialog() async {
    TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1B3A2D) : Colors.white,
          title: Text("Analysis Caption", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: "Enter a name for this session...",
              hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text("Analyze", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  Future<void> _playAnalyzingAnimation() async {
    final stages = [
      "Extracting frames...",
      "Running player tracking model...",
      "Generating tactical analysis...",
      "Calculating advanced metrics...",
      "Finalizing report..."
    ];
    for (String stage in stages) {
      if (!mounted) break;
      setState(() => _analyzingText = stage);
      await Future.delayed(const Duration(milliseconds: 1200));
    }
  }

  // ── Data loaders (Uploaded data) ────────────────────────────────────────────
  Future<void> _loadSummary() async {
    try {
      final json = await rootBundle.loadString('assets/output_analysis_green_team2_balanced/analysis_summary.json');
      final map = jsonDecode(json) as Map<String, dynamic>;
      _upTotalFrames = (map['total_frames'] as num?)?.toInt() ?? 0;
      _upFramesWithPossession = (map['frames_with_possession'] as num?)?.toInt() ?? 0;
    } catch (_) {}
  }

  Future<void> _loadSpeedData() async {
    try {
      final csv = await rootBundle.loadString('assets/output_analysis_green_team2_balanced/player_metrics.csv');
      final lines = csv.split('\n');
      List<FlSpot> spots = [];
      int step = lines.length ~/ 150;
      if (step == 0) step = 1;
      for (int i = 1; i < lines.length; i += step) {
        if (lines[i].trim().isEmpty) continue;
        final cols = lines[i].split(',');
        if (cols.length >= 5) {
          double frame = double.tryParse(cols[0]) ?? 0;
          double speed = double.tryParse(cols[4]) ?? 0;
          spots.add(FlSpot(frame, speed));
        }
      }
      spots.sort((a, b) => a.x.compareTo(b.x));
      _upSpeedData = spots;
    } catch (_) {
      _upSpeedData = const [FlSpot(0, 3), FlSpot(1, 1)];
    }
  }

  Future<void> _loadPossessionData() async {
    try {
      final csv = await rootBundle.loadString('assets/output_analysis_green_team2_balanced/ball_possession.csv');
      final lines = csv.split('\n');
      List<FlSpot> spots = [];
      const bucket = 100;
      int possCount = 0;
      int bucketStart = 0;
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        final cols = lines[i].split(',');
        if (cols.length >= 4) {
          int frame = int.tryParse(cols[0]) ?? 0;
          bool hasPoss = cols[3].trim().toLowerCase() == 'true';
          if (frame >= bucketStart + bucket) {
            double pct = (possCount / bucket) * 100;
            spots.add(FlSpot(bucketStart.toDouble(), pct));
            bucketStart = (frame ~/ bucket) * bucket;
            possCount = 0;
          }
          if (hasPoss) possCount++;
        }
      }
      if (possCount > 0) {
        double pct = (possCount / bucket) * 100;
        spots.add(FlSpot(bucketStart.toDouble(), pct));
      }
      spots.sort((a, b) => a.x.compareTo(b.x));
      _upPossessionData = spots;
    } catch (_) {
      _upPossessionData = [];
    }
  }

  Future<void> _loadPassesData() async {
    try {
      final csv = await rootBundle.loadString('assets/output_analysis_green_team2_balanced/passes.csv');
      final lines = csv.split('\n');
      _upTotalPasses = lines.where((l) => l.trim().isNotEmpty).length - 1;
    } catch (_) {
      _upTotalPasses = 0;
    }
  }

  Future<void> _loadInterceptionsData() async {
    try {
      final csv = await rootBundle.loadString('assets/output_analysis_green_team2_balanced/interceptions.csv');
      final lines = csv.split('\n');
      _upTotalInterceptions = lines.where((l) => l.trim().isNotEmpty).length - 1;
    } catch (_) {
      _upTotalInterceptions = 0;
    }
  }

  // ── UI Builders ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(title: "Equipo's Lens", showTeamSwitcher: true),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16).copyWith(top: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Always show the upload box at the very top
                _buildSectionTitle("NEW ANALYSIS", textColor, isMainTitle: true),
                const SizedBox(height: 16),
                _buildUploadBox(cardBg, textColor, subtitleColor),
                const SizedBox(height: 32),

                // Uploaded Content Section
                if (_videoUploaded) ...[
                  _buildSectionTitle(_uploadedCaption, textColor, isMainTitle: true),
                  const SizedBox(height: 16),
                  _buildSummaryRow(
                    _upTotalPasses, 
                    _upTotalInterceptions, 
                    _upTotalFrames > 0 ? ((_upFramesWithPossession / _upTotalFrames) * 100).toStringAsFixed(1) : '—', 
                    cardBg, textColor, subtitleColor
                  ),
                  const SizedBox(height: 16),
                  _buildMetricSelector(isDark, textColor, false),
                  const SizedBox(height: 12),
                  _buildMainChart(cardBg, textColor, subtitleColor, false),
                  const SizedBox(height: 16),
                  _buildVideoCard(
                    cardBg, textColor, 
                    hasVideo: _uploadedVideoPath != null,
                    isLoading: false,
                    onTap: _playUploadedVideo,
                  ),
                  const SizedBox(height: 40),
                ],

                // Static Section
                _buildSectionTitle("ANGOLA'S GAME", textColor, isMainTitle: true),
                const SizedBox(height: 16),
                _buildSummaryRow(112, 45, "48.5", cardBg, textColor, subtitleColor),
                const SizedBox(height: 16),
                _buildMetricSelector(isDark, textColor, true),
                const SizedBox(height: 12),
                _buildMainChart(cardBg, textColor, subtitleColor, true),
                const SizedBox(height: 16),
                _buildVideoCard(
                  cardBg, textColor, 
                  hasVideo: true,
                  isLoading: _extractingStaticVideo,
                  onTap: _playStaticVideo,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor, {bool isMainTitle = false}) {
    return Text(
      title,
      style: isMainTitle 
        ? const TextStyle(fontFamily: 'Facon', fontSize: 20, color: Colors.white, letterSpacing: 1.5)
        : TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5, color: textColor),
    );
  }

  Widget _buildUploadBox(Color cardBg, Color textColor, Color subtitleColor) {
    return GestureDetector(
      onTap: (_isUploading || _isAnalyzing) ? null : _pickVideo,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardBg.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade700, width: 2, style: BorderStyle.solid),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isUploading || _isAnalyzing) ...[
              const SizedBox(
                width: 40, height: 40,
                child: CircularProgressIndicator(color: Colors.green, strokeWidth: 4),
              ),
              const SizedBox(height: 24),
              Text(
                "ANALYZING VIDEO...",
                style: TextStyle(fontFamily: 'Facon', fontSize: 18, color: textColor, letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  _isUploading ? "Uploading..." : _analyzingText,
                  key: ValueKey(_isUploading ? "Uploading..." : _analyzingText),
                  style: TextStyle(fontSize: 13, color: subtitleColor, fontStyle: FontStyle.italic),
                ),
              ),
            ] else ...[
              Icon(Icons.video_library_rounded, size: 48, color: Colors.green.shade600),
              const SizedBox(height: 16),
              Text("Upload Video for Analysis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              Text("AI processing takes ~15 seconds", style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.7))),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(int passes, int ints, String possPct, Color cardBg, Color textColor, Color subtitleColor) {
    return Row(
      children: [
        Expanded(child: _summaryCard(Icons.sports_handball_rounded, "$passes", "Passes", cardBg, textColor, subtitleColor)),
        const SizedBox(width: 10),
        Expanded(child: _summaryCard(Icons.shield_rounded, "$ints", "Interceptions", cardBg, textColor, subtitleColor)),
        const SizedBox(width: 10),
        Expanded(child: _summaryCard(Icons.pie_chart_rounded, "$possPct%", "Possession", cardBg, textColor, subtitleColor)),
      ],
    );
  }

  Widget _summaryCard(IconData icon, String value, String label, Color cardBg, Color textColor, Color subtitleColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.green, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Facon', color: textColor)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: subtitleColor), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildMetricSelector(bool isDark, Color textColor, bool isStatic) {
    final chipBg = isDark ? const Color(0xFF0A1F15) : Colors.grey.shade100;
    final currentMetric = isStatic ? _staticSelectedMetric : _upSelectedMetric;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _metricChip("Ball's Speed", "speed", chipBg, isDark, isStatic, currentMetric),
          const SizedBox(width: 8),
          _metricChip("Possession", "possession", chipBg, isDark, isStatic, currentMetric),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String metric, Color chipBg, bool isDark, bool isStatic, String currentMetric) {
    final selected = currentMetric == metric;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isStatic) _staticSelectedMetric = metric;
          else _upSelectedMetric = metric;
        });
      },
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

  Widget _buildMainChart(Color cardBg, Color textColor, Color subtitleColor, bool isStatic) {
    final metric = isStatic ? _staticSelectedMetric : _upSelectedMetric;
    final speedData = isStatic ? _staticSpeedData : _upSpeedData;
    final possData = isStatic ? _staticPossessionData : _upPossessionData;
    
    final data = metric == 'speed' ? speedData : possData;
    final yLabel = metric == 'speed' ? 'Ball\'s Speed (km/h)' : 'Possession %';
    final chartColor = metric == 'speed' ? Colors.green : const Color(0xFF1565C0);

    double maxX = 0; double maxY = 0;
    for (var spot in data) {
      if (spot.x > maxX) maxX = spot.x;
      if (spot.y > maxY) maxY = spot.y;
    }
    maxY = maxY > 0 ? maxY * 1.2 : 50;
    if (maxX == 0) maxX = 100;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(yLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 16),
          Expanded(
            child: data.isEmpty
                ? Center(child: Text("No data available", style: TextStyle(color: subtitleColor)))
                : LineChart(
                    LineChartData(
                      minX: data.first.x, maxX: maxX, minY: 0, maxY: maxY,
                      gridData: FlGridData(
                        show: true, drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(color: textColor.withValues(alpha: 0.08), strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, reservedSize: 30,
                            getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: TextStyle(fontSize: 10, color: subtitleColor)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, reservedSize: 20, interval: (maxX / 5) > 0 ? (maxX / 5) : 1,
                            getTitlesWidget: (value, meta) => Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('F${value.toInt()}', style: TextStyle(fontSize: 9, color: subtitleColor)),
                            ),
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: data, isCurved: true, color: chartColor, barWidth: 2, isStrokeCapRound: true, dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: true, color: chartColor.withValues(alpha: 0.15)),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(Color cardBg, Color textColor, {
    required bool hasVideo,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: hasVideo && !isLoading ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Analyzed Play", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A1F15), Color(0xFF1B3A2D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: isLoading
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 36, height: 36,
                          child: CircularProgressIndicator(color: Colors.green, strokeWidth: 3),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Preparing video...",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Tap to play video",
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Opens in system player",
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
