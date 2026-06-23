import 'package:eqq/core/app_localizations.dart';
import 'package:flutter/material.dart';
import '../services/file_cache_service.dart';
// import 'GameHistoryModel.dart';
//
// class GameDetailView extends StatelessWidget {
//   final GameHistory game;
//
//   const GameDetailView({super.key, required this.game});
//
//   @override
//   Widget build(BuildContext context) {
//     final bool won = game.ourScore > game.theirScore;
//
//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         scrolledUnderElevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           "VS ${game.opponent.toUpperCase()}",
//           style: const TextStyle(
//             color: Colors.black,
//             fontWeight: FontWeight.bold,
//             fontSize: 18,
//             letterSpacing: 1.2,
//           ),
//         ),
//       ),
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Colors.green, Colors.white],
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//           ),
//           image: DecorationImage(
//             image: AssetImage("assets/background.png"),
//             fit: BoxFit.cover,
//             opacity: 0.2,
//           ),
//         ),
//         child: SafeArea(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const SizedBox(height: 8),
//
//                 // ✅ Score box — matches screenshot 2
//                 _buildScoreCard(won),
//                 const SizedBox(height: 24),
//
//                 // ✅ Game stats table
//                 _buildSectionTitle("GAME STATS"),
//                 const SizedBox(height: 10),
//                 _buildStatsTable(),
//                 const SizedBox(height: 24),
//
//                 // ✅ PDF files section
//                 _buildSectionTitle("GAME FILES"),
//                 const SizedBox(height: 10),
//                 _buildPdfSection(),
//                 const SizedBox(height: 24),
//
//                 // ✅ Game videos section
//                 _buildSectionTitle("GAME VIDEOS"),
//                 const SizedBox(height: 10),
//                 _buildVideosSection(),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildScoreCard(bool won) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         // Our score
//         Container(
//           width: 90,
//           height: 90,
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withValues(alpha: 0.08),
//                 blurRadius: 6,
//                 offset: const Offset(0, 3),
//               ),
//             ],
//           ),
//           child: Center(
//             child: Text(
//               "${game.ourScore}",
//               style: const TextStyle(
//                 fontSize: 36,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black,
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(width: 16),
//         // Arrow icon
//         Icon(
//           won ? Icons.arrow_forward : Icons.arrow_back,
//           color: Colors.green,
//           size: 28,
//         ),
//         const SizedBox(width: 16),
//         // Their score
//         Container(
//           width: 90,
//           height: 90,
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withValues(alpha: 0.08),
//                 blurRadius: 6,
//                 offset: const Offset(0, 3),
//               ),
//             ],
//           ),
//           child: Center(
//             child: Text(
//               "${game.theirScore}",
//               style: const TextStyle(
//                 fontSize: 36,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildSectionTitle(String title) {
//     return Text(
//       title,
//       style: const TextStyle(
//         fontWeight: FontWeight.bold,
//         fontSize: 16,
//         letterSpacing: 0.5,
//       ),
//     );
//   }
//
//   Widget _buildStatsTable() {
//     return Column(
//       children: game.stats.map((stat) {
//         return Container(
//           margin: const EdgeInsets.only(bottom: 8),
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withValues(alpha: 0.05),
//                 blurRadius: 4,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 stat["title"] ?? "",
//                 style: const TextStyle(
//                   fontWeight: FontWeight.bold,
//                   fontSize: 14,
//                 ),
//               ),
//               Text(
//                 stat["value"] ?? "",
//                 style: const TextStyle(fontSize: 14),
//               ),
//             ],
//           ),
//         );
//       }).toList(),
//     );
//   }
//
//   Widget _buildPdfSection() {
//     return Column(
//       children: game.pdfFiles.map((fileName) {
//         return Container(
//           margin: const EdgeInsets.only(bottom: 10),
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withValues(alpha: 0.05),
//                 blurRadius: 4,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Row(
//             children: [
//               const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Text(
//                   fileName,
//                   style: const TextStyle(
//                     fontWeight: FontWeight.w500,
//                     fontSize: 14,
//                   ),
//                 ),
//               ),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.green,
//                   minimumSize: const Size(60, 32),
//                   padding: const EdgeInsets.symmetric(horizontal: 12),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                 ),
//                 onPressed: () {
//                   // TODO: open PDF
//                 },
//                 child: const Text("open", style: TextStyle(fontSize: 13)),
//               ),
//               const SizedBox(width: 8),
//               IconButton(
//                 icon: const Icon(Icons.download, color: Colors.black54),
//                 onPressed: () {
//                   // TODO: download PDF
//                 },
//               ),
//             ],
//           ),
//         );
//       }).toList(),
//     );
//   }
//
//   Widget _buildVideosSection() {
//     return Column(
//       children: game.videos.map((video) {
//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               video["title"] ?? "",
//               style: const TextStyle(
//                 fontSize: 15,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//             const SizedBox(height: 8),
//             // ✅ Video thumbnail placeholder
//             Container(
//               height: 180,
//               decoration: BoxDecoration(
//                 color: Colors.black87,
//                 borderRadius: BorderRadius.circular(12),
//                 image: video["thumbnail"] != null
//                     ? DecorationImage(
//                   image: AssetImage(video["thumbnail"]!),
//                   fit: BoxFit.cover,
//                   opacity: 0.7,
//                 )
//                     : null,
//               ),
//               child: Center(
//                 child: Container(
//                   width: 52,
//                   height: 52,
//                   decoration: const BoxDecoration(
//                     color: Colors.white,
//                     shape: BoxShape.circle,
//                   ),
//                   child: const Icon(
//                     Icons.play_arrow,
//                     color: Colors.black,
//                     size: 32,
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),
//           ],
//         );
//       }).toList(),
//     );
//   }
// }


// import 'package:flutter/material.dart';
import '../services/file_cache_service.dart';
// import 'GameHistoryModel.dart';
//
// class GameDetailHistoryView extends StatefulWidget {
//   final GameHistory game;
//   final String userRole; // ✅ passed from TeamStats
//
//   const GameDetailHistoryView({
//     super.key,
//     required this.game,
//     required this.userRole,
//   });
//
//   @override
//   State<GameDetailHistoryView> createState() => _GameDetailViewState();
// }
//
// class _GameDetailViewState extends State<GameDetailHistoryView> {
//   // ✅ Coach notes stored locally per game view session
//   final List<Map<String, String>> _notes = [];
//   final TextEditingController _noteController = TextEditingController();
//
//   @override
//   void dispose() {
//     _noteController.dispose();
//     super.dispose();
//   }
//
//   void _addNote() {
//     final text = _noteController.text.trim();
//     if (text.isEmpty) return;
//     setState(() {
//       _notes.add({
//         "name": "Ahmed Mahmoud", // TODO: replace with logged-in user name
//         "role": "Coach",
//         "text": text,
//       });
//       _noteController.clear();
//     });
//   }
//
//   void _openPdf(String fileName) {
//     // TODO: when Firebase is ready, fetch download URL and open with url_launcher:
//     // final url = await FirebaseStorage.instance.ref(fileName).getDownloadURL();
//     // await launchUrl(Uri.parse(url));
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("Opening $fileName... (Firebase not connected yet)")),
//     );
//   }
//
//   void _downloadPdf(String fileName) {
//     // TODO: when Firebase is ready, download file to device:
//     // final url = await FirebaseStorage.instance.ref(fileName).getDownloadURL();
//     // download via http + path_provider
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("Downloading $fileName... (Firebase not connected yet)")),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final bool won = widget.game.ourScore > widget.game.theirScore;
//     final bool isCoach = widget.userRole.trim() == "Coach";
//
//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         scrolledUnderElevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           "VS ${widget.game.opponent.toUpperCase()}",
//           style: const TextStyle(
//             color: Colors.black,
//             fontWeight: FontWeight.bold,
//             fontSize: 18,
//             letterSpacing: 1.2,
//           ),
//         ),
//       ),
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Colors.green, Colors.white],
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//           ),
//           image: DecorationImage(
//             image: AssetImage("assets/background.png"),
//             fit: BoxFit.cover,
//             opacity: 0.2,
//           ),
//         ),
//         child: SafeArea(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const SizedBox(height: 8),
//                 _buildScoreCard(won),
//                 const SizedBox(height: 24),
//                 _buildSectionTitle("GAME STATS"),
//                 const SizedBox(height: 10),
//                 _buildStatsTable(),
//                 const SizedBox(height: 24),
//                 _buildSectionTitle("GAME FILES"),
//                 const SizedBox(height: 10),
//                 _buildPdfSection(),
//                 const SizedBox(height: 24),
//                 _buildSectionTitle("GAME VIDEOS"),
//                 const SizedBox(height: 10),
//                 _buildVideosSection(),
//                 const SizedBox(height: 24),
//
//                 // ✅ Coach notes section — visible to all, editable only by Coach
//                 _buildSectionTitle("COACH NOTES"),
//                 const SizedBox(height: 10),
//                 _buildCoachNotes(isCoach),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildScoreCard(bool won) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         _scoreBox("${widget.game.ourScore}"),
//         const SizedBox(width: 16),
//         Icon(
//           won ? Icons.arrow_forward : Icons.arrow_back,
//           color: Colors.green,
//           size: 28,
//         ),
//         const SizedBox(width: 16),
//         _scoreBox("${widget.game.theirScore}"),
//       ],
//     );
//   }
//
//   Widget _scoreBox(String score) {
//     return Container(
//       width: 90,
//       height: 90,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 3)),
//         ],
//       ),
//       child: Center(
//         child: Text(
//           score,
//           style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSectionTitle(String title) {
//     return Text(
//       title,
//       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
//     );
//   }
//
//   Widget _buildStatsTable() {
//     return Column(
//       children: widget.game.stats.map((stat) {
//         return Container(
//           margin: const EdgeInsets.only(bottom: 8),
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(stat["title"] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
//               Text(stat["value"] ?? "", style: const TextStyle(fontSize: 14)),
//             ],
//           ),
//         );
//       }).toList(),
//     );
//   }
//
//   Widget _buildPdfSection() {
//     return Column(
//       children: widget.game.pdfFiles.map((fileName) {
//         return Container(
//           margin: const EdgeInsets.only(bottom: 10),
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
//           ),
//           child: Row(
//             children: [
//               const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Text(fileName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
//               ),
//               // ✅ Open button — will use Firebase URL when connected
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.green,
//                   minimumSize: const Size(60, 32),
//                   padding: const EdgeInsets.symmetric(horizontal: 12),
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                 ),
//                 onPressed: () => _openPdf(fileName),
//                 child: const Text("open", style: TextStyle(fontSize: 13)),
//               ),
//               const SizedBox(width: 4),
//               // ✅ Download button — will use Firebase URL when connected
//               IconButton(
//                 icon: const Icon(Icons.download, color: Colors.black54),
//                 onPressed: () => _downloadPdf(fileName),
//               ),
//             ],
//           ),
//         );
//       }).toList(),
//     );
//   }
//
//   Widget _buildVideosSection() {
//     return Column(
//       children: widget.game.videos.map((video) {
//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(video["title"] ?? "", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
//             const SizedBox(height: 8),
//             Container(
//               height: 180,
//               decoration: BoxDecoration(
//                 color: Colors.black87,
//                 borderRadius: BorderRadius.circular(12),
//                 image: video["thumbnail"] != null
//                     ? DecorationImage(
//                   image: AssetImage(video["thumbnail"]!),
//                   fit: BoxFit.cover,
//                   opacity: 0.7,
//                 )
//                     : null,
//               ),
//               child: Center(
//                 child: Container(
//                   width: 52,
//                   height: 52,
//                   decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
//                   child: const Icon(Icons.play_arrow, color: Colors.black, size: 32),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),
//           ],
//         );
//       }).toList(),
//     );
//   }
//
//   Widget _buildCoachNotes(bool isCoach) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // ✅ Existing notes
//         if (_notes.isEmpty && !isCoach)
//           const Text("No coach notes yet.", style: TextStyle(color: Colors.black45)),
//
//         ..._notes.map((note) => Container(
//           margin: const EdgeInsets.only(bottom: 10),
//           padding: const EdgeInsets.all(14),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // ✅ Coach avatar + name row matching screenshot
//               Row(
//                 children: [
//                   const CircleAvatar(
//                     radius: 22,
//                     backgroundImage: AssetImage("assets/profile.png"),
//                   ),
//                   const SizedBox(width: 10),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(note["name"] ?? "",
//                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
//                       Text(note["role"] ?? "",
//                           style: const TextStyle(color: Colors.black54, fontSize: 13)),
//                     ],
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 10),
//               Text(note["text"] ?? "", style: const TextStyle(fontSize: 14)),
//             ],
//           ),
//         )),
//
//         // ✅ Add note input — only visible to Coach role
//         if (isCoach) ...[
//           const SizedBox(height: 8),
//           TextField(
//             controller: _noteController,
//             maxLines: 3,
//             decoration: InputDecoration(
//               filled: true,
//               fillColor: Colors.white,
//               hintText: "Write a note...",
//               border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//             ),
//           ),
//           const SizedBox(height: 8),
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.green,
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 minimumSize: const Size(double.infinity, 48),
//               ),
//               onPressed: _addNote,
//               child: const Text("Save Note"),
//             ),
//           ),
//         ],
//       ],
//     );
//   }
// }


// import 'package:flutter/material.dart';
import '../services/file_cache_service.dart';
// import '../core/app_localizations.dart';
import '../appbar/CustomAppBar.dart';
// import 'GameHistoryModel.dart';
//
// class GameDetailHistoryView extends StatefulWidget {
//   final GameHistory game;
//   final String userRole;
//
//   const GameDetailHistoryView({
//     super.key,
//     required this.game,
//     required this.userRole,
//   });
//
//   @override
//   State<GameDetailHistoryView> createState() => _GameDetailViewState();
// }
//
// class _GameDetailViewState extends State<GameDetailHistoryView> {
//   final List<Map<String, String>> _notes = [];
//   final TextEditingController _noteController = TextEditingController();
//
//   @override
//   void dispose() {
//     _noteController.dispose();
//     super.dispose();
//   }
//
//   void _addNote() {
//     final text = _noteController.text.trim();
//     if (text.isEmpty) return;
//     setState(() {
//       _notes.add({
//         "name": "Ahmed Mahmoud",
//         "role": "Coach",
//         "text": text,
//       });
//       _noteController.clear();
//     });
//   }
//
//   void _openPdf(String fileName) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("Opening $fileName... (Firebase not connected yet)")),
//     );
//   }
//
//   void _downloadPdf(String fileName) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("Downloading $fileName... (Firebase not connected yet)")),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final bool won = widget.game.ourScore > widget.game.theirScore;
//     final bool isCoach = widget.userRole.trim() == "Coach";
//
//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: CustomAppBar(title: AppLocalizations.of(context).vsOpponent(widget.game.opponent.toUpperCase()), showTeamSwitcher: true),
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Colors.green, Colors.white],
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//           ),
//           image: DecorationImage(
//             image: AssetImage("assets/background.png"),
//             fit: BoxFit.cover,
//             opacity: 0.2,
//           ),
//         ),
//         child: SafeArea(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const SizedBox(height: 8),
//                 _buildScoreCard(won),
//                 const SizedBox(height: 24),
//                 _buildSectionTitle("GAME STATS"),
//                 const SizedBox(height: 10),
//                 _buildStatsTable(),
//                 const SizedBox(height: 24),
//                 _buildSectionTitle("GAME FILES"),
//                 const SizedBox(height: 10),
//                 _buildPdfSection(),
//                 const SizedBox(height: 24),
//                 _buildSectionTitle("GAME VIDEOS"),
//                 const SizedBox(height: 10),
//                 _buildVideosSection(),
//                 const SizedBox(height: 24),
//                 _buildSectionTitle("COACH NOTES"),
//                 const SizedBox(height: 10),
//                 _buildCoachNotes(isCoach),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildScoreCard(bool won) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         _scoreBox("${widget.game.ourScore}"),
//         const SizedBox(width: 16),
//         Icon(
//           won ? Icons.arrow_forward : Icons.arrow_back,
//           color: Colors.green,
//           size: 28,
//         ),
//         const SizedBox(width: 16),
//         _scoreBox("${widget.game.theirScore}"),
//       ],
//     );
//   }
//
//   Widget _scoreBox(String score) {
//     return Container(
//       width: 90,
//       height: 90,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 3)),
//         ],
//       ),
//       child: Center(
//         child: Text(
//           score,
//           style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSectionTitle(String title) {
//     return Text(
//       title,
//       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
//     );
//   }
//
//   Widget _buildStatsTable() {
//     return Column(
//       children: widget.game.stats.map((stat) {
//         return Container(
//           margin: const EdgeInsets.only(bottom: 8),
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(stat["title"] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
//               Text(stat["value"] ?? "", style: const TextStyle(fontSize: 14)),
//             ],
//           ),
//         );
//       }).toList(),
//     );
//   }
//
//   Widget _buildPdfSection() {
//     return Column(
//       children: widget.game.pdfFiles.map((fileName) {
//         return Container(
//           margin: const EdgeInsets.only(bottom: 10),
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
//           ),
//           child: Row(
//             children: [
//               const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Text(fileName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
//               ),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.green,
//                   minimumSize: const Size(60, 32),
//                   padding: const EdgeInsets.symmetric(horizontal: 12),
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                 ),
//                 onPressed: () => _openPdf(fileName),
//                 child: const Text("open", style: TextStyle(fontSize: 13)),
//               ),
//               const SizedBox(width: 4),
//               IconButton(
//                 icon: const Icon(Icons.download, color: Colors.black54),
//                 onPressed: () => _downloadPdf(fileName),
//               ),
//             ],
//           ),
//         );
//       }).toList(),
//     );
//   }
//
//   Widget _buildVideosSection() {
//     return Column(
//       children: widget.game.videos.map((video) {
//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(video["title"] ?? "", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
//             const SizedBox(height: 8),
//             Container(
//               height: 180,
//               decoration: BoxDecoration(
//                 color: Colors.black87,
//                 borderRadius: BorderRadius.circular(12),
//                 image: video["thumbnail"] != null
//                     ? DecorationImage(
//                   image: AssetImage(video["thumbnail"]!),
//                   fit: BoxFit.cover,
//                   opacity: 0.7,
//                 )
//                     : null,
//               ),
//               child: Center(
//                 child: Container(
//                   width: 52,
//                   height: 52,
//                   decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
//                   child: const Icon(Icons.play_arrow, color: Colors.black, size: 32),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),
//           ],
//         );
//       }).toList(),
//     );
//   }
//
//   Widget _buildCoachNotes(bool isCoach) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         if (_notes.isEmpty && !isCoach)
//           const Text("No coach notes yet.", style: TextStyle(color: Colors.black45)),
//
//         ..._notes.map((note) => Container(
//           margin: const EdgeInsets.only(bottom: 10),
//           padding: const EdgeInsets.all(14),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   const CircleAvatar(
//                     radius: 22,
//                     backgroundImage: AssetImage("assets/profile.png"),
//                   ),
//                   const SizedBox(width: 10),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(note["name"] ?? "",
//                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
//                       Text(note["role"] ?? "",
//                           style: const TextStyle(color: Colors.black54, fontSize: 13)),
//                     ],
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 10),
//               Text(note["text"] ?? "", style: const TextStyle(fontSize: 14)),
//             ],
//           ),
//         )),
//
//         if (isCoach) ...[
//           const SizedBox(height: 8),
//           TextField(
//             controller: _noteController,
//             maxLines: 3,
//             decoration: InputDecoration(
//               filled: true,
//               fillColor: Colors.white,
//               hintText: "Write a note...",
//               border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//             ),
//           ),
//           const SizedBox(height: 8),
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.green,
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 minimumSize: const Size(double.infinity, 48),
//               ),
//               onPressed: _addNote,
//               child: const Text("Save Note"),
//             ),
//           ),
//         ],
//       ],
//     );
//   }
// }

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/file_cache_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../appbar/CustomAppBar.dart';
import '../core/animated_button.dart';
import '../core/app_background.dart';
import '../core/network_video_player_screen.dart';
import '../core/smooth_keyboard_mixin.dart';
import '../models/api_models.dart';
import '../services/coach_note_service.dart';
import '../services/event_document_service.dart';
import '../services/game_video_service.dart';
import '../services/stats_service.dart';
import 'GameHistoryModel.dart';

class GameDetailHistoryView extends StatefulWidget {
  final GameHistory game;
  final String userRole;

  const GameDetailHistoryView({
    super.key,
    required this.game,
    required this.userRole,
  });

  @override
  State<GameDetailHistoryView> createState() => _GameDetailViewState();
}

class _GameDetailViewState extends State<GameDetailHistoryView> with TickerProviderStateMixin, SmoothKeyboardMixin {
  final CoachNoteService _noteService = CoachNoteService();
  List<CoachNoteDto> _notes = [];
  bool _notesLoading = false;
  bool _notesSaving = false;
  String? _editingNoteId;
  final TextEditingController _noteController = TextEditingController();

  final EventDocumentService _docService = EventDocumentService();
  List<EventDocumentDto> _documents = [];
  bool _docsLoading = false;
  String? _openingDocumentId;
  bool _uploadingDoc = false;

  final StatsService _statsService = StatsService();
  bool _hasRawPdf = false;
  String? _rawPdfFileName;
  bool _openingRawPdf = false;

  final GameVideoService _videoService = GameVideoService();
  List<GameVideoDto> _videos = [];
  bool _videosLoading = false;
  bool _savingVideo = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _loadNotes();
    _loadStatsPdf();
    _loadVideos();
  }

  void _loadVideos() {
    final game = widget.game;
    if (game.eventId == null || game.clubId == null || game.teamId == null) return;
    setState(() => _videosLoading = true);
    _videoService
        .getVideos(game.clubId!, game.teamId!, game.eventId!)
        .then((videos) {
          if (mounted) setState(() { _videos = videos; _videosLoading = false; });
        })
        .catchError((_) {
          if (mounted) setState(() => _videosLoading = false);
        });
  }

  void _loadStatsPdf() {
    final game = widget.game;
    if (game.eventId == null || game.clubId == null || game.teamId == null) return;
    _statsService
        .getMatchContext(game.clubId!, game.teamId!, game.eventId!)
        .then((ctx) {
          if (!mounted) return;
          setState(() {
            _hasRawPdf = ctx['hasRawPdf'] == true;
            _rawPdfFileName = ctx['rawPdfFileName']?.toString();
          });
        })
        .catchError((_) {});
  }

  Future<void> _openRawStatsPdf() async {
    if (_openingRawPdf) return;
    final game = widget.game;
    if (game.eventId == null || game.clubId == null || game.teamId == null) return;
    setState(() => _openingRawPdf = true);
    try {
      final tempFile = await FileCacheService.instance.getFile('/clubs/${game.clubId}/teams/${game.teamId}/stats/matches/${game.eventId}/raw-pdf', extension: '.pdf', contentType: 'application/pdf');
      if (!mounted) return;
      final openResult = await OpenFilex.open(tempFile.path, type: 'application/pdf');
      if (openResult.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).openFileErrorMsg.replaceAll('%s', openResult.message))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).statsPdfError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _openingRawPdf = false);
    }
  }

  void _loadNotes() {
    final game = widget.game;
    if (game.eventId == null || game.clubId == null || game.teamId == null) return;
    setState(() => _notesLoading = true);
    _noteService
        .getNotes(game.clubId!, game.teamId!, game.eventId!)
        .then((notes) {
          if (mounted) setState(() { _notes = notes; _notesLoading = false; });
        })
        .catchError((_) {
          if (mounted) setState(() => _notesLoading = false);
        });
  }

  void _loadDocuments() {
    final game = widget.game;
    if (game.eventId == null || game.clubId == null || game.teamId == null) return;
    setState(() => _docsLoading = true);
    _docService
        .getEventDocuments(game.clubId!, game.teamId!, game.eventId!)
        .then((docs) {
          if (mounted) setState(() { _documents = docs; _docsLoading = false; });
        })
        .catchError((_) {
          if (mounted) setState(() => _docsLoading = false);
        });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _addOrUpdateNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty || _notesSaving) return;
    final game = widget.game;
    if (game.eventId == null || game.clubId == null || game.teamId == null) return;
    setState(() => _notesSaving = true);
    try {
      if (_editingNoteId != null) {
        final updated = await _noteService.updateNote(
            game.clubId!, game.teamId!, game.eventId!, _editingNoteId!, text);
        final idx = _notes.indexWhere((n) => n.noteId == _editingNoteId);
        if (mounted) {
          setState(() {
            if (idx != -1) _notes[idx] = updated;
            _editingNoteId = null;
            _noteController.clear();
          });
        }
      } else {
        final created = await _noteService.createNote(
            game.clubId!, game.teamId!, game.eventId!, text);
        if (mounted) {
          setState(() {
            _notes.insert(0, created);
            _noteController.clear();
          });
        }
      }
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).saveNoteError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _notesSaving = false);
    }
  }

  void _startEditNote(CoachNoteDto note) {
    setState(() {
      _editingNoteId = note.noteId;
      _noteController.text = note.body;
    });
  }

  Future<void> _confirmDeleteNote(CoachNoteDto note) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete_rounded, color: Colors.red),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).deleteNoteTitle,
                      style: const TextStyle(
                        color: Color(0xFF001F14),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'SFPro',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                AppLocalizations.of(context).deleteNoteDesc,
                style: const TextStyle(
                  color: Color(0xFF4D5B53),
                  fontSize: 14,
                  height: 1.35,
                  fontFamily: 'SFPro',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF001F14),
                        side: BorderSide(
                          color: Colors.black.withValues(alpha: 0.12),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(AppLocalizations.of(context).cancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(AppLocalizations.of(context).delete),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (shouldDelete == true) {
      final game = widget.game;
      if (game.eventId == null || game.clubId == null || game.teamId == null) return;
      try {
        await _noteService.deleteNote(
            game.clubId!, game.teamId!, game.eventId!, note.noteId);
        if (mounted) {
          setState(() {
            _notes.removeWhere((n) => n.noteId == note.noteId);
            if (_editingNoteId == note.noteId) {
              _editingNoteId = null;
              _noteController.clear();
            }
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).deleteNoteError(e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _openDocument(EventDocumentDto doc) async {
    if (_openingDocumentId != null) return;
    setState(() => _openingDocumentId = doc.documentId);
    try {
      final ext = doc.originalFileName.contains('.') ? '.${doc.originalFileName.split('.').last}' : '';
      final tempFile = await FileCacheService.instance.getFile('/events/documents/${doc.documentId}/download', extension: ext, contentType: doc.contentType);
      if (!mounted) return;
      final openResult = await OpenFilex.open(tempFile.path, type: doc.contentType);
      if (openResult.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).openFileError(openResult.message))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).openDocumentError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _openingDocumentId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    updateKeyboardHeight(MediaQuery.viewInsetsOf(context).bottom);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasOpponentScore = widget.game.theirScore >= 0;
    final bool won = hasOpponentScore && widget.game.ourScore > widget.game.theirScore;
    final String roleLower = widget.userRole.trim().toLowerCase();
    final bool isAnalyst = roleLower == "teamanalyst";
    const Set<String> noteRoles = {
      "coach", "teammanager", "teamanalyst", "teamdoctor", "fitnesscoach", "clubmanager",
    };
    final bool canPostNotes = noteRoles.contains(roleLower);
    final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: CustomAppBar(title: AppLocalizations.of(context).vsOpponent(widget.game.opponent.toUpperCase()), showTeamSwitcher: true),
      body: buildKeyboardDismissible(child: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16).copyWith(bottom: 16 + smoothKeyboardHeight, top: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildScoreCard(won, hasOpponentScore, cardBg, textColor),
                const SizedBox(height: 24),
                _buildSectionTitle(AppLocalizations.of(context).gameStatsTitle, textColor),
                const SizedBox(height: 10),
                _buildStatsTable(cardBg, textColor),
                const SizedBox(height: 24),
                _buildSectionTitle(AppLocalizations.of(context).gameFilesTitle, textColor),
                const SizedBox(height: 10),
                _buildPdfSection(cardBg, textColor, isAnalyst),
                const SizedBox(height: 24),
                _buildSectionTitle(AppLocalizations.of(context).gameVideosTitle, textColor),
                const SizedBox(height: 10),
                _buildVideosSection(cardBg, textColor, isAnalyst),
                const SizedBox(height: 24),
                _buildSectionTitle(AppLocalizations.of(context).coachNotesTitle, textColor),
                const SizedBox(height: 10),
                _buildCoachNotes(canPostNotes, isDark, cardBg, textColor, subtitleColor),
              ],
            ),
          ),
        ),
      )),
    );
  }

  Widget _buildScoreCard(
    bool won,
    bool hasOpponentScore,
    Color cardBg,
    Color textColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _scoreBox("${widget.game.ourScore}", cardBg, textColor),
        const SizedBox(width: 16),
        Text(
          "-",
          style: TextStyle(
            fontFamily: 'Facon',
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(width: 16),
        _scoreBox(
          hasOpponentScore ? "${widget.game.theirScore}" : "-",
          cardBg,
          textColor,
        ),
      ],
    );
  }

  Widget _scoreBox(String score, Color cardBg, Color textColor) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Center(
        child: Text(score,
            style: TextStyle(
                fontFamily: 'Facon',
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: textColor)),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(title,
        style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
            color: textColor));
  }

  Widget _buildStatsTable(Color cardBg, Color textColor) {
    return Column(
      children: widget.game.stats.map((stat) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(stat["title"] ?? "",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor)),
              Text(stat["value"] ?? "",
                  style: TextStyle(fontSize: 14, color: textColor)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _pickAndUploadGameFile() async {
    if (_uploadingDoc) return;
    final game = widget.game;
    if (game.eventId == null || game.clubId == null || game.teamId == null) return;

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(type: FileType.any);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).filePickerError(e.toString()))),
        );
      }
      return;
    }
    if (picked == null || picked.files.isEmpty || !mounted) return;

    final file = picked.files.single;
      if (file == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).fileReadError)),
          );
        }
        return;
      }

    final descController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF001F14);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: dialogBg,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).uploadGameFileTitle,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'SFPro')),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined,
                      color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.7),
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).descOptional,
                  hintStyle:
                      TextStyle(color: textColor.withValues(alpha: 0.4)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: Colors.green.withValues(alpha: 0.3))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: Colors.green, width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(
                            color: textColor.withValues(alpha: 0.12)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(AppLocalizations.of(context).cancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(AppLocalizations.of(context).upload),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result != true) return;

    setState(() => _uploadingDoc = true);
    try {
      final desc = descController.text.trim();
      final created = await _docService.uploadDocument(
        game.clubId!,
          game.teamId!,
          game.eventId!,
          file,
          desc.isEmpty ? null : desc,
        );
      if (mounted) {
        setState(() => _documents.insert(0, created));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).fileUploaded)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).fileUploadError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingDoc = false);
    }
  }

  Widget _buildPdfSection(Color cardBg, Color textColor, bool isAnalyst) {
    return Column(
      children: [
        if (isAnalyst)
          GestureDetector(
            onTap: _uploadingDoc ? null : _pickAndUploadGameFile,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1),
              ),
              child: Column(
                children: [
                  _uploadingDoc
                      ? const SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.green),
                        )
                      : const Icon(Icons.upload_file_outlined,
                          color: Colors.green, size: 40),
                  const SizedBox(height: 8),
                  Text(_uploadingDoc ? AppLocalizations.of(context).uploading : AppLocalizations.of(context).uploadGameFile,
                      style: TextStyle(
                          color: textColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        if (_hasRawPdf) _buildRawStatsCard(cardBg, textColor),
        if (_docsLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: Colors.green)),
          )
        else if (_documents.isEmpty && !_hasRawPdf && !isAnalyst)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(AppLocalizations.of(context).noDocsUploaded, style: TextStyle(color: textColor.withValues(alpha: 0.5))),
          )
        else
          ..._documents.map((doc) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: Colors.red, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.originalFileName,
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: textColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (doc.description != null && doc.description!.isNotEmpty)
                          Text(
                            doc.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  AnimatedButton.primary(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(60, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _openingDocumentId != null ? null : () => _openDocument(doc),
                      child: _openingDocumentId == doc.documentId
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                            )
                          : Text(AppLocalizations.of(context).open,
                              style: TextStyle(fontSize: 13, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRawStatsCard(Color cardBg, Color textColor) {
    final name = (_rawPdfFileName != null && _rawPdfFileName!.trim().isNotEmpty)
        ? _rawPdfFileName!
        : AppLocalizations.of(context).matchStatsPdf;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.assessment, color: Colors.green, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14, color: textColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  AppLocalizations.of(context).originalStatsSheet,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          AnimatedButton.primary(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(60, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _openingRawPdf ? null : _openRawStatsPdf,
              child: _openingRawPdf
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(AppLocalizations.of(context).open,
                      style: TextStyle(fontSize: 13, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openVideo(GameVideoDto video) async {
    final url = await _videoService.authorizedStreamUrl(video);
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).videoUnavailable)),
        );
      }
      return;
    }
    // Token is in the URL; headers are kept as a belt-and-suspenders fallback.
    final headers = await _videoService.streamHeaders();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NetworkVideoPlayerScreen(
          url: url,
          headers: headers,
          title: video.title,
        ),
      ),
    );
  }

  // 500 MB, matching the server-side cap.
  static const int _maxVideoBytes = 500 * 1024 * 1024;

  Future<void> _showAddVideoDialog() async {
    if (_savingVideo) return;

    // 1. Pick a video file from the device.
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(type: FileType.video);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).filePickerError(e.toString()))),
        );
      }
      return;
    }
    if (picked == null || picked.files.isEmpty || !mounted) return;

    final file = picked.files.single;
      if (file == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).fileReadError)),
          );
        }
        return;
      }
    if (file.size > _maxVideoBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).videoTooLarge)),
        );
      }
      return;
    }

    // 2. Confirm with an optional title.
    final titleController = TextEditingController(
      text: file.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF001F14);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: dialogBg,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).uploadGameVideoTitle,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'SFPro')),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.movie_outlined,
                      color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.7),
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).titleOptional,
                  hintStyle:
                      TextStyle(color: textColor.withValues(alpha: 0.4)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: Colors.green.withValues(alpha: 0.3))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: Colors.green, width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(
                            color: textColor.withValues(alpha: 0.12)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(AppLocalizations.of(context).cancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(AppLocalizations.of(context).upload),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      await _addVideo(titleController.text.trim(), file);
    }
  }

  Future<void> _addVideo(String title, PlatformFile file) async {
    if (_savingVideo) return;
    final game = widget.game;
    if (game.eventId == null || game.clubId == null || game.teamId == null) return;
    setState(() => _savingVideo = true);

    try {
      final created = await _videoService.uploadVideo(
          game.clubId!, game.teamId!, game.eventId!, title, file);
      if (mounted) {
        setState(() => _videos.insert(0, created));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).videoUploaded)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).videoUploadFailed} ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingVideo = false);
    }
  }

  Future<void> _confirmDeleteVideo(GameVideoDto video) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).removeVideoTitle),
        content: Text(AppLocalizations.of(context).removeVideoDesc(video.title)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context).cancel)),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context).remove)),
        ],
      ),
    );
    if (shouldDelete != true) return;
    final game = widget.game;
    if (game.eventId == null || game.clubId == null || game.teamId == null) return;
    try {
      await _videoService.deleteVideo(
          game.clubId!, game.teamId!, game.eventId!, video.videoId);
      if (mounted) {
        setState(() => _videos.removeWhere((v) => v.videoId == video.videoId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).videoRemoveError} ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildVideosSection(Color cardBg, Color textColor, bool isAnalyst) {
    return Column(
      children: [
        if (isAnalyst)
          GestureDetector(
            onTap: _savingVideo ? null : _showAddVideoDialog,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1),
              ),
              child: Column(
                children: [
                  _savingVideo
                      ? const SizedBox(
                          width: 30, height: 30,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.green),
                        )
                      : const Icon(Icons.video_call_outlined,
                          color: Colors.green, size: 40),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context).uploadGameVideo,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        if (_videosLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: Colors.green)),
          )
        else if (_videos.isEmpty && !isAnalyst)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(AppLocalizations.of(context).noVideosYet,
                style: TextStyle(color: textColor.withValues(alpha: 0.5))),
          )
        else
          ..._videos.map((video) {
            return Card(
              color: cardBg,
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: textColor.withValues(alpha: 0.1), width: 1),
              ),
              child: InkWell(
                onTap: () => _openVideo(video),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(Icons.play_circle_fill_rounded,
                              color: Colors.green, size: 36),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video.title.isNotEmpty ? video.title : 'Game Video',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (video.addedByName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Added by ${video.addedByName}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textColor.withValues(alpha: 0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ]
                          ],
                        ),
                      ),
                      if (video.canEdit)
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: textColor.withValues(alpha: 0.5), size: 22),
                          onPressed: () => _confirmDeleteVideo(video),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCoachNotes(bool canPostNotes, bool isDark, Color cardBg,
      Color textColor, Color subtitleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_notesLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: Colors.green)),
          )
        else if (_notes.isEmpty && !canPostNotes)
          Text(AppLocalizations.of(context).noCoachNotesYet,
              style: TextStyle(color: subtitleColor)),

        ..._notes.map((note) {
          final borderColor = isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.07);
          final avatarUrl = note.authorAvatarUrl;
          final ImageProvider avatarImage =
              (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                  ? NetworkImage(avatarUrl)
                  : const AssetImage("assets/profile.png") as ImageProvider;

          return _NoteActionSlider(
            enabled: note.canEdit,
            onEdit: () => _startEditNote(note),
            onDelete: () => _confirmDeleteNote(note),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.fromLTRB(24, 22, 18, 18),
              decoration: BoxDecoration(
                color: cardBg,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.green.withValues(alpha: 0.14),
                        backgroundImage: avatarImage,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(note.authorName,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                    color: textColor,
                                    fontFamily: 'SFPro',
                                    height: 1.28)),
                            const SizedBox(height: 7),
                            Text(note.authorRole,
                                style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'SFPro',
                                    height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(note.body,
                      style: TextStyle(
                          fontSize: 15,
                          color: textColor.withValues(alpha: 0.9),
                          height: 1.5)),
                ],
              ),
            ),
          );
        }),

        if (canPostNotes) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 4,
            minLines: 1,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: cardBg,
              hintText: AppLocalizations.of(context).writeNote,
              hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.green.withValues(alpha: 0.3))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.green.withValues(alpha: 0.3))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.green, width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AnimatedButton.primary(child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                minimumSize: const Size(double.infinity, 54),
              ),
              onPressed: _notesSaving ? null : _addOrUpdateNote,
              child: _notesSaving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_editingNoteId != null ? AppLocalizations.of(context).updateNoteTitle : AppLocalizations.of(context).postNote,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            )),
          ),
        ],
      ],
    );
  }
}

class _NoteActionSlider extends StatefulWidget {
  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool enabled;

  const _NoteActionSlider({
    required this.child,
    required this.onEdit,
    required this.onDelete,
    this.enabled = true,
  });

  @override
  State<_NoteActionSlider> createState() => _NoteActionSliderState();
}

class _NoteActionSliderState extends State<_NoteActionSlider> {
  static const double _actionWidth = 152;
  double _offset = 0;

  bool get _isOpen => _offset <= -_actionWidth / 2;

  void _snap({required bool open}) {
    setState(() => _offset = open ? -_actionWidth : 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.centerEnd,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: widget.enabled ? (details) {
            setState(() {
              _offset = (_offset + details.delta.dx).clamp(-_actionWidth, 0);
            });
          } : null,
          onHorizontalDragEnd: widget.enabled ? (_) => _snap(open: _isOpen) : null,
          onTap: _offset == 0 ? null : () => _snap(open: false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: widget.child,
          ),
        ),
        if (_offset < 0)
          Positioned.fill(
            bottom: 16,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: -_offset,
                  child: Row(
                    children: [
                      Expanded(
                        child: _NoteActionButton(
                          color: Colors.blue,
                          icon: Icons.edit_rounded,
                          label: AppLocalizations.of(context).edit,
                          onTap: () {
                            _snap(open: false);
                            widget.onEdit();
                          },
                        ),
                      ),
                      Expanded(
                        child: _NoteActionButton(
                          color: Colors.red,
                          icon: Icons.delete_rounded,
                          label: AppLocalizations.of(context).delete,
                          onTap: () {
                            _snap(open: false);
                            widget.onDelete();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NoteActionButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NoteActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

