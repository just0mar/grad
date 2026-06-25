import 'package:eqq/core/app_localizations.dart';
import '../core/app_video_player.dart';
import '../core/cached_image_widget.dart';
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/file_cache_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/animated_button.dart';
import '../core/app_background.dart';
import '../core/app_transitions.dart';
import '../core/document_manager.dart';
import '../location/location_point.dart';
import '../location/location_service.dart';
import '../location/osm_map.dart';
import '../services/api_client.dart';
import 'ChatModel.dart';
import 'chat_bloc.dart';

class ChatView extends StatelessWidget {
  final String conversationId;
  final String personName;
  final String personImage;
  final String? teamName;
  final bool isGroup;
  final String currentUserId;

  const ChatView({
    super.key,
    required this.conversationId,
    required this.personName,
    required this.personImage,
    this.teamName,
    this.isGroup = false,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ChatBloc(conversationId: conversationId, currentUserId: currentUserId)
            ..add(LoadChatMessages()),
      child: _ChatBody(
        personName: personName,
        personImage: personImage,
        teamName: teamName,
        isGroup: isGroup,
        currentUserId: currentUserId,
      ),
    );
  }
}

class _ChatBody extends StatefulWidget {
  final String personName;
  final String personImage;
  final String? teamName;
  final bool isGroup;
  final String currentUserId;

  const _ChatBody({
    required this.personName,
    required this.personImage,
    this.teamName,
    this.isGroup = false,
    required this.currentUserId,
  });

  @override
  State<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<_ChatBody> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showEmoji = false;
  bool _hasText = false;
  double _keyboardHeight = 0;
  ChatMessage? _replyingTo;

  // Voice recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isRecordingLocked = false;
  double _recordDragDx = 0;
  double _recordDragDy = 0;
  DateTime? _recordingStart;
  Timer? _recordingTimer;
  String _recordingDuration = '0:00';

  static const _reactions = [
    '\u{1F44D}',
    '\u{2764}\u{FE0F}',
    '\u{1F602}',
    '\u{1F62E}',
    '\u{1F622}',
    '\u{1F64F}',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
    _focusNode.addListener(() {
      // When keyboard appears (focus gained), hide emoji picker
      if (_focusNode.hasFocus && _showEmoji) {
        setState(() => _showEmoji = false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .viewInsets
        .bottom;
    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final keyboardH = bottomInset / pixelRatio;
    if (keyboardH > 100 && keyboardH != _keyboardHeight) {
      setState(() => _keyboardHeight = keyboardH);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final reply = _replyingTo;
    final messageText = reply == null ? text : _composeReplyText(reply, text);
    context.read<ChatBloc>().add(SendMessage(messageText));
    _textController.clear();
    setState(() => _replyingTo = null);
    _scrollToBottom();
  }

  String _composeReplyText(ChatMessage reply, String text) {
    final author = _replySafe(reply.fromMe ? 'You' : widget.personName);
    final snippet = _replySafe(_messageSnippet(reply));
    return '[reply|$author|$snippet]\n$text';
  }

  String _replySafe(String value) =>
      value.replaceAll('|', '/').replaceAll('\n', ' ').trim();

  String _messageSnippet(ChatMessage message) {
    return _replyPreviewTextForMessage(message);
  }

  // ── Voice recording ──────────────────────────────
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        setState(() {
          _isRecording = true;
          _isRecordingLocked = false;
          _recordDragDx = 0;
          _recordDragDy = 0;
          _recordingStart = DateTime.now();
          _recordingDuration = '0:00';
        });
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_recordingStart != null) {
            final elapsed = DateTime.now().difference(_recordingStart!);
            setState(() {
              _recordingDuration =
                  '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
            });
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).couldNotStartRecording)),
        );
      }
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordingTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isRecordingLocked = false;
        _recordDragDx = 0;
        _recordDragDy = 0;
        _recordingStart = null;
        _recordingDuration = '0:00';
      });
      if (path != null && mounted) {
        context.read<ChatBloc>().add(SendVoiceNote(path));
        _scrollToBottom();
      }
    } catch (_) {
      setState(() => _isRecording = false);
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
      _recordDragDx = 0;
      _recordDragDy = 0;
      _recordingStart = null;
      _recordingDuration = '0:00';
    });
  }

  Future<void> _handleMicLongPressStart(LongPressStartDetails details) async {
    if (_hasText || _isRecording) return;
    await _startRecording();
  }

  Future<void> _startLockedRecording() async {
    if (_hasText || _isRecording) return;
    await _startRecording();
    if (!mounted || !_isRecording) return;
    setState(() => _isRecordingLocked = true);
  }

  void _handleMicLongPressMove(LongPressMoveUpdateDetails details) {
    if (!_isRecording || _isRecordingLocked) return;
    final offset = details.localOffsetFromOrigin;
    setState(() {
      _recordDragDx = offset.dx;
      _recordDragDy = offset.dy;
    });
    if (offset.dy < -58) {
      setState(() {
        _isRecordingLocked = true;
        _recordDragDx = 0;
        _recordDragDy = 0;
      });
    } else if (offset.dx < -96) {
      _cancelRecording();
    }
  }

  Future<void> _handleMicLongPressEnd(LongPressEndDetails details) async {
    if (!_isRecording || _isRecordingLocked) return;
    if (_recordDragDx < -80) {
      await _cancelRecording();
    } else {
      await _stopAndSendRecording();
    }
  }

  // ── Attachment + menu ────────────────────────────
  void _showAttachmentMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = Colors.green.shade700;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  runSpacing: 16,
                  spacing: 18,
                  children: [
                    _AttachOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: iconColor,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(ctx);
                        _openCamera();
                      },
                    ),
                    _AttachOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      color: iconColor,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(ctx);
                        _openGallery();
                      },
                    ),
                    _AttachOption(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Document',
                      color: iconColor,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickDocument();
                      },
                    ),
                    _AttachOption(
                      icon: Icons.poll_rounded,
                      label: 'Poll',
                      color: iconColor,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showPollDialog();
                      },
                    ),
                    _AttachOption(
                      icon: Icons.my_location_rounded,
                      label: 'Current\nLocation',
                      color: iconColor,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendCurrentLocation();
                      },
                    ),
                    _AttachOption(
                      icon: Icons.map_rounded,
                      label: 'Map pin',
                      color: iconColor,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSendLocation();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCamera() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera, color: Colors.green.shade700),
              title: Text(
                'Take Photo',
                style: TextStyle(fontFamily: 'SFPro', color: textColor),
              ),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
            ListTile(
              leading: Icon(Icons.videocam, color: Colors.green.shade700),
              title: Text(
                'Record Video',
                style: TextStyle(fontFamily: 'SFPro', color: textColor),
              ),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final picker = ImagePicker();
    final XFile? file;
    if (choice == 'photo') {
      file = await picker.pickImage(source: ImageSource.camera);
    } else {
      file = await picker.pickVideo(source: ImageSource.camera);
    }
    if (file == null || !mounted) return;

    // Show caption/confirmation screen
    if (!mounted) return;
    final result = await Navigator.push<_MediaCaptionResult>(
      context,
      AppPageRoute(
        child: _MediaCaptionPage(files: [file], isVideo: choice == 'video'),
      ),
    );
    if (result == null || !mounted) return;
    for (final f in result.files) {
        final bytes = kIsWeb ? await f.readAsBytes() : null;
        if (!mounted) return;
        context.read<ChatBloc>().add(
          SendMediaMessage(
            fileBytes: bytes,
            filePath: kIsWeb ? null : f.path,
            fileName: f.name,
            caption: result.caption,
          ),
        );
      }
    _scrollToBottom();
  }

  Future<void> _openGallery() async {
    final picker = ImagePicker();
    final files = await picker.pickMultipleMedia();
    if (files.isEmpty || !mounted) return;

    // Show caption/confirmation screen
    final result = await Navigator.push<_MediaCaptionResult>(
      context,
      AppPageRoute(child: _MediaCaptionPage(files: files, isVideo: false)),
    );
    if (result == null || !mounted) return;
    for (int i = 0; i < result.files.length; i++) {
      final f = result.files[i];
      context.read<ChatBloc>().add(
        SendMediaMessage(
          filePath: f.path,
          fileName: f.name,
          // Only attach caption to the last file
          caption: i == result.files.length - 1 ? result.caption : null,
        ),
      );
    }
    _scrollToBottom();
  }

  Future<void> _pickDocument() async {
    final result = await DocumentManager.pickDocument(
      context: context,
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'txt',
        'zip',
      ],
    );
    final file = result?.files.single;
    if (file == null || !mounted) return;
    context.read<ChatBloc>().add(
      SendMediaMessage(fileBytes: file.bytes, filePath: kIsWeb ? null : file.path, fileName: file.name),
    );
    _scrollToBottom();
  }

  Future<void> _pickAndSendLocation() async {
    final result = await Navigator.push<LocationPoint>(
      context,
      AppPageRoute(child: const OsmLocationPicker()),
    );
    if (result == null || !mounted) return;
    context.read<ChatBloc>().add(SendLocationMessage(result));
    _scrollToBottom();
  }

  Future<void> _sendCurrentLocation() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context).gettingLocation),
            ],
          ),
          duration: const Duration(seconds: 15),
        ),
      );

      final point = await LocationService().getCurrentLocation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      context.read<ChatBloc>().add(SendLocationMessage(point));
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).couldNotGetLocation.replaceAll('%s', e.toString()))),
        );
      }
    }
  }

  void _showPollDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dlgBg = isDark ? const Color(0xFF1B3A2D) : const Color(0xFFF5F5F0);
    final textColor = isDark ? Colors.white : Colors.black;
    final questionCtrl = TextEditingController();
    final optionCtrls = [TextEditingController(), TextEditingController()];
    var allowMultipleAnswers = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: dlgBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                'Create Poll',
                style: TextStyle(
                  fontFamily: 'SFPro',
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _pollField(questionCtrl, 'Question', isDark, textColor),
                    const SizedBox(height: 12),
                    ...optionCtrls.asMap().entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _pollField(
                          e.value,
                          'Option ${e.key + 1}',
                          isDark,
                          textColor,
                        ),
                      );
                    }),
                    if (optionCtrls.length < 6)
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(
                            () => optionCtrls.add(TextEditingController()),
                          );
                        },
                        icon: Icon(Icons.add, color: Colors.green.shade700),
                        label: Text(
                          'Add Option',
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    SwitchListTile.adaptive(
                      value: allowMultipleAnswers,
                      activeThumbColor: Colors.green.shade700,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Allow multiple answers',
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() => allowMultipleAnswers = value);
                      },
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(
                            color: isDark
                                ? Colors.white12
                                : Colors.grey.shade300,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontFamily: 'SFPro'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedButton.primary(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            final q = questionCtrl.text.trim();
                            final opts = optionCtrls
                                .map((c) => c.text.trim())
                                .where((t) => t.isNotEmpty)
                                .toList();
                            if (q.isEmpty || opts.length < 2) return;
                            final pollText =
                                '\u{1F4CA} Poll: $q\n${allowMultipleAnswers ? '[Multiple answers]' : '[Single answer]'}\n${opts.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}';
                            context.read<ChatBloc>().add(SendMessage(pollText));
                            Navigator.pop(ctx);
                            _scrollToBottom();
                          },
                          child: const Text(
                            'Send',
                            style: TextStyle(
                              fontFamily: 'SFPro',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _pollField(
    TextEditingController ctrl,
    String hint,
    bool isDark,
    Color textColor,
  ) {
    return TextField(
      controller: ctrl,
      style: TextStyle(fontFamily: 'SFPro', color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'SFPro',
          color: isDark ? Colors.white38 : Colors.grey,
        ),
        filled: true,
        fillColor: isDark ? Colors.grey.shade800 : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
      ),
    );
  }

  // ── Message actions ──────────────────────────────
  void _showMessageActions(ChatMessage message) {
    if (message.isDeleted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reactions row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _reactions.map((emoji) {
                      final hasReacted = message.reactions.any(
                        (r) =>
                            r.userId == widget.currentUserId &&
                            r.emoji == emoji,
                      );
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          context.read<ChatBloc>().add(
                            ToggleReaction(
                              messageId: message.messageId,
                              emoji: emoji,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: hasReacted
                                ? Colors.green.shade700.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
                if (message.fromMe) ...[
                  ListTile(
                    leading: Icon(Icons.visibility, color: textColor),
                    title: Text(
                      'Seen by',
                      style: TextStyle(fontFamily: 'SFPro', color: textColor),
                    ),
                    subtitle: Text(
                      '${message.seenByCount}/${message.requiredSeenCount}',
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showSeenByDialog(message);
                    },
                  ),
                ],
                if (message.canEditOrDelete) ...[
                  ListTile(
                    leading: Icon(Icons.edit, color: textColor),
                    title: Text(
                      'Edit',
                      style: TextStyle(fontFamily: 'SFPro', color: textColor),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showEditDialog(message);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text(
                      'Delete',
                      style: TextStyle(fontFamily: 'SFPro', color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.read<ChatBloc>().add(
                        DeleteMessage(message.messageId),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSeenByDialog(ChatMessage message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dlgBg = isDark ? const Color(0xFF1B3A2D) : const Color(0xFFF5F5F0);
    final textColor = isDark ? Colors.white : Colors.black;
    final seenBy = message.seenBy;

    showModalBottomSheet(
      context: context,
      backgroundColor: dlgBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seen by',
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${message.seenByCount}/${message.requiredSeenCount} members',
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                if (seenBy.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No one has seen this message yet.',
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: seenBy.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      itemBuilder: (_, index) {
                        final receipt = seenBy[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _buildProfileAvatar(
                            receipt.profileImageUrl,
                            radius: 18,
                          ),
                          title: Text(
                            receipt.userName.isEmpty
                                ? 'Team member'
                                : receipt.userName,
                            style: TextStyle(
                              fontFamily: 'SFPro',
                              color: textColor,
                            ),
                          ),
                          subtitle: Text(
                            DateFormat(
                              'MMM d, HH:mm',
                            ).format(receipt.readAt.toLocal()),
                            style: TextStyle(
                              fontFamily: 'SFPro',
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(ChatMessage message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dlgBg = isDark ? const Color(0xFF1B3A2D) : const Color(0xFFF5F5F0);
    final textColor = isDark ? Colors.white : Colors.black;
    final editController = TextEditingController(text: message.text);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dlgBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Edit Message',
            style: TextStyle(
              fontFamily: 'SFPro',
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          content: TextField(
            controller: editController,
            autofocus: true,
            maxLines: 4,
            style: TextStyle(fontFamily: 'SFPro', color: textColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? Colors.grey.shade800 : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontFamily: 'SFPro'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedButton.primary(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        final newText = editController.text.trim();
                        if (newText.isNotEmpty && newText != message.text) {
                          context.read<ChatBloc>().add(
                            EditMessage(
                              messageId: message.messageId,
                              newContent: newText,
                            ),
                          );
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _toggleEmoji() {
    if (_showEmoji) {
      // Hide emojis, show keyboard
      setState(() => _showEmoji = false);
      _focusNode.requestFocus();
    } else {
      // Show emojis, hide keyboard
      FocusScope.of(context).unfocus();
      Future.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) return;
        setState(() => _showEmoji = true);
      });
    }
  }

  Widget _buildProfileAvatar(String? imageUrl, {double radius = 18}) {
    final resolved = ApiClient.resolveUrl(imageUrl);
    if (resolved != null && resolved.isNotEmpty) {
      return ClipOval(
        child: CachedImageWidget(
          imageUrl: resolved,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorWidget: Container(
            color: Colors.grey.shade400,
            child: Icon(Icons.person, color: Colors.white, size: radius),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade400,
      child: Icon(Icons.person, color: Colors.white, size: radius),
    );
  }

  // ── Build ────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 30,
        title: Row(
          children: [
            _buildProfileAvatar(widget.personImage, radius: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.personName,
                    style: const TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.teamName != null && widget.teamName!.isNotEmpty)
                    Text(
                      widget.teamName!,
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Messages list
            Expanded(
              child: BlocConsumer<ChatBloc, ChatState>(
                listener: (context, state) {
                  if (state.error != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(state.error!)));
                  }
                },
                builder: (context, state) {
                  if (state.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.messages.isEmpty) {
                    return Center(
                      child: Text(
                        'No messages yet. Say hello!',
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: state.messages.length + (state.isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (state.isSending && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white54 : Colors.black54),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Uploading...', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, fontFamily: 'SFPro')),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final msgIndex = state.isSending ? index - 1 : index;
                      final message = state.messages[msgIndex];
                      final showDate =
                          msgIndex == state.messages.length - 1 ||
                          !_isSameDay(
                            message.sentAt,
                            state.messages[msgIndex + 1].sentAt,
                          );

                      return Column(
                        key: ValueKey(message.messageId),
                        children: [
                          if (showDate)
                            _DateChip(date: message.sentAt, isDark: isDark),
                          RepaintBoundary(
                            child: _MessageBubble(
                              message: message,
                              isDark: isDark,
                              currentUserId: widget.currentUserId,
                              isGroup: widget.isGroup,
                              onReply: () =>
                                  setState(() => _replyingTo = message),
                              onLongPress: () => _showMessageActions(message),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            // Input bar
            if (_replyingTo != null)
              _ReplyPreview(
                message: _replyingTo!,
                authorName: _replyingTo!.fromMe ? 'You' : widget.personName,
                isDark: isDark,
                onCancel: () => setState(() => _replyingTo = null),
              ),
            _buildInputBar(isDark),
            // Emoji picker (appears in place of keyboard)
            if (_showEmoji)
              Container(
                height: _keyboardHeight > 100 ? _keyboardHeight : 280,
                color: isDark ? const Color(0xFF0A1F15) : Colors.white,
                child: SafeArea(
                  top: false,
                  child: GridView.count(
                    crossAxisCount: 8,
                    padding: const EdgeInsets.all(8),
                  children: _commonEmojis.map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        _textController.text += emoji;
                        _textController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _textController.text.length),
                        );
                      },
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    final barBg = isDark ? const Color(0xFF0A1F15) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF1B3A2D) : const Color(0xFFF0F5F2);
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white54 : Colors.grey.shade600;

    // Recording mode
    if (_isRecording) {
      final cancelProgress = (_recordDragDx.abs() / 96)
          .clamp(0.0, 1.0)
          .toDouble();
      final lockProgress = ((-_recordDragDy) / 58).clamp(0.0, 1.0).toDouble();
      return Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        color: barBg,
        child: SafeArea(
          top: false,
          bottom: !_showEmoji,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (!_isRecordingLocked)
                Positioned(
                  right: 0,
                  bottom: 54,
                  child: AnimatedOpacity(
                    opacity: (0.55 + lockProgress * 0.45)
                        .clamp(0.0, 1.0)
                        .toDouble(),
                    duration: const Duration(milliseconds: 120),
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        _recordDragDy.clamp(-42.0, 0.0).toDouble(),
                      ),
                      child: Container(
                        width: 46,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: fieldBg,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock,
                              size: 18,
                              color: lockProgress >= 1
                                  ? Colors.green.shade700
                                  : iconColor,
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              Icons.keyboard_arrow_up,
                              size: 18,
                              color: iconColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isRecordingLocked
                          ? Icons.delete_outline
                          : Icons.keyboard_arrow_left_rounded,
                      color: Colors.red,
                    ),
                    onPressed: _cancelRecording,
                  ),
                  Expanded(
                    child: AnimatedSlide(
                      offset: Offset(
                        _isRecordingLocked
                            ? 0
                            : (_recordDragDx / 240)
                                  .clamp(-0.28, 0.0)
                                  .toDouble(),
                        0,
                      ),
                      duration: const Duration(milliseconds: 90),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: fieldBg,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mic, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _recordingDuration,
                              style: const TextStyle(
                                fontFamily: 'SFPro',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: _RecordingWave(isDark: isDark)),
                            if (!_isRecordingLocked) ...[
                              const SizedBox(width: 8),
                              Opacity(
                                opacity: (1 - cancelProgress)
                                    .clamp(0.35, 1.0)
                                    .toDouble(),
                                child: Text(
                                  'Slide left to cancel',
                                  style: TextStyle(
                                    fontFamily: 'SFPro',
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isRecordingLocked ? Icons.send : Icons.mic,
                        color: Colors.white,
                        size: _isRecordingLocked ? 20 : 22,
                      ),
                      onPressed: _isRecordingLocked
                          ? _stopAndSendRecording
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Normal input mode
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      color: barBg,
      child: SafeArea(
        top: false,
        bottom: !_showEmoji,
        child: Row(
          children: [
            // Emoji toggle
            IconButton(
              icon: Icon(
                _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                color: iconColor,
              ),
              onPressed: _toggleEmoji,
            ),
            // Text field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        onTap: () {
                          if (_showEmoji) {
                            setState(() => _showEmoji = false);
                          }
                        },
                        maxLines: 4,
                        minLines: 1,
                        style: TextStyle(fontFamily: 'SFPro', color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Type a message',
                          hintStyle: TextStyle(
                            fontFamily: 'SFPro',
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _sendText(),
                      ),
                    ),
                    // + attachment menu
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: iconColor),
                      onPressed: _showAttachmentMenu,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Send or Mic button
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                shape: BoxShape.circle,
              ),
              child: _hasText
                  ? IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _sendText,
                    )
                  : GestureDetector(
                      onTap: _startLockedRecording,
                      onLongPressStart: _handleMicLongPressStart,
                      onLongPressMoveUpdate: _handleMicLongPressMove,
                      onLongPressEnd: _handleMicLongPressEnd,
                      child: const Center(
                        child: Icon(Icons.mic, color: Colors.white, size: 22),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static const _commonEmojis = [
    '\u{1F600}',
    '\u{1F603}',
    '\u{1F604}',
    '\u{1F601}',
    '\u{1F606}',
    '\u{1F605}',
    '\u{1F602}',
    '\u{1F923}',
    '\u{1F60A}',
    '\u{1F607}',
    '\u{1F970}',
    '\u{1F60D}',
    '\u{1F929}',
    '\u{1F618}',
    '\u{1F617}',
    '\u{1F61A}',
    '\u{1F60B}',
    '\u{1F61B}',
    '\u{1F61C}',
    '\u{1F92A}',
    '\u{1F61D}',
    '\u{1F911}',
    '\u{1F917}',
    '\u{1F92D}',
    '\u{1F914}',
    '\u{1F910}',
    '\u{1F928}',
    '\u{1F610}',
    '\u{1F611}',
    '\u{1F636}',
    '\u{1F60F}',
    '\u{1F612}',
    '\u{1F644}',
    '\u{1F62C}',
    '\u{1F925}',
    '\u{1F60C}',
    '\u{1F614}',
    '\u{1F62A}',
    '\u{1F924}',
    '\u{1F634}',
    '\u{1F637}',
    '\u{1F912}',
    '\u{1F915}',
    '\u{1F922}',
    '\u{1F92E}',
    '\u{1F927}',
    '\u{1F975}',
    '\u{1F976}',
    '\u{1F44D}',
    '\u{1F44E}',
    '\u{1F44F}',
    '\u{1F64C}',
    '\u{1F91D}',
    '\u{1F64F}',
    '\u{270D}\u{FE0F}',
    '\u{1F4AA}',
    '\u{2764}\u{FE0F}',
    '\u{1F9E1}',
    '\u{1F49B}',
    '\u{1F49A}',
    '\u{1F499}',
    '\u{1F49C}',
    '\u{1F5A4}',
    '\u{1F494}',
  ];
}

// ═══════════════════════════════════════════════════
// ATTACH OPTION (for the + menu)
// ═══════════════════════════════════════════════════
class _ReplySwipeWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool enabled;

  const _ReplySwipeWrapper({
    required this.child,
    required this.onReply,
    required this.enabled,
  });

  @override
  State<_ReplySwipeWrapper> createState() => _ReplySwipeWrapperState();
}

class _ReplySwipeWrapperState extends State<_ReplySwipeWrapper> {
  static const double _maxOffset = 72;
  static const double _triggerOffset = 46;
  double _offset = 0;

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    final delta = details.primaryDelta ?? 0;
    setState(() {
      _offset = (_offset + delta).clamp(-_maxOffset, _maxOffset);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    if (_offset.abs() >= _triggerOffset) {
      widget.onReply();
    }
    setState(() => _offset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final iconAlignment = _offset >= 0
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final opacity = (_offset.abs() / _triggerOffset).clamp(0.0, 1.0);

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: iconAlignment,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Opacity(
                  opacity: opacity,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.green.shade700.withValues(
                      alpha: 0.16,
                    ),
                    child: Icon(
                      Icons.reply,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onHorizontalDragCancel: () => setState(() => _offset = 0),
          child: AnimatedContainer(
            duration: _offset == 0
                ? const Duration(milliseconds: 150)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _ReplyData {
  final String author;
  final String snippet;

  const _ReplyData({required this.author, required this.snippet});
}

String _replyPreviewTextForMessage(ChatMessage message) {
  if (message.isDeleted) return 'Deleted message';
  final attachmentLabel = _attachmentReplyLabel(message);
  if (attachmentLabel != null) return attachmentLabel;
  final raw = message.text
      .replaceFirst(RegExp(r'^\[reply\|[^\n]*\]\s*'), '')
      .replaceAll('\n', ' ')
      .trim();
  return raw.isEmpty ? 'Message' : raw;
}

String? _attachmentReplyLabel(ChatMessage message) {
  final type = message.messageType.toLowerCase();
  final fileName = message.mediaFileName?.trim();
  final hasAttachment =
      type != 'text' ||
      message.mediaUrl?.isNotEmpty == true ||
      fileName?.isNotEmpty == true;
  if (!hasAttachment) return null;
  if (type.contains('image')) return 'Photo';
  if (type.contains('video')) return 'Video';
  if (type.contains('audio') || type.contains('voice')) return 'Voice note';
  if (type.contains('location')) return 'Location';
  return _documentReplyLabel(fileName);
}

String _documentReplyLabel(String? fileName) {
  final lower = fileName?.toLowerCase() ?? '';
  if (lower.endsWith('.pdf')) return 'PDF document';
  if (RegExp(r'\.(doc|docx)$').hasMatch(lower)) return 'Word document';
  if (RegExp(r'\.(xls|xlsx|csv)$').hasMatch(lower)) return 'Spreadsheet';
  if (RegExp(r'\.(ppt|pptx)$').hasMatch(lower)) return 'Presentation';
  if (RegExp(r'\.(zip|rar|7z)$').hasMatch(lower)) return 'Archive';
  return 'Document';
}

class _ReplyPreview extends StatelessWidget {
  final ChatMessage message;
  final String authorName;
  final bool isDark;
  final VoidCallback onCancel;

  const _ReplyPreview({
    required this.message,
    required this.authorName,
    required this.isDark,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? const Color(0xFF0A1F15) : Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
      child: Row(
        children: [
          Container(width: 4, height: 42, color: Colors.green.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _previewText(message),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: isDark ? Colors.white60 : Colors.black45,
            ),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }

  String _previewText(ChatMessage message) {
    return _replyPreviewTextForMessage(message);
  }
}

class _ReplyQuote extends StatelessWidget {
  final _ReplyData data;
  final bool isDark;

  const _ReplyQuote({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.18)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: Colors.green.shade700, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'SFPro',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.snippet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'SFPro',
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'SFPro',
              fontSize: 12,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// RECORDING WAVE ANIMATION
// ═══════════════════════════════════════════════════
class _RecordingWave extends StatelessWidget {
  final bool isDark;
  const _RecordingWave({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(20, (i) {
        final height = 4.0 + (i % 3 + 1) * 4.0;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            height: height,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════
// DATE CHIP
// ═══════════════════════════════════════════════════
class _DateChip extends StatelessWidget {
  final DateTime date;
  final bool isDark;

  const _DateChip({required this.date, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(date, now)) {
      label = 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      label = DateFormat('dd/MM/yyyy').format(date);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'SFPro',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ═══════════════════════════════════════════════════
// MESSAGE BUBBLE
// ═══════════════════════════════════════════════════
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  final String currentUserId;
  final bool isGroup;
  final VoidCallback onReply;
  final VoidCallback onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isDark,
    required this.currentUserId,
    this.isGroup = false,
    required this.onReply,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.fromMe;
    final bubbleColor = isMe
        ? (isDark ? const Color(0xFF1B3A2D) : const Color(0xFFD6F5E0))
        : (isDark ? const Color(0xFF0D2A1C) : Colors.white);
    final textColor = isDark ? Colors.white : Colors.black;
    final timeColor = isDark ? Colors.white38 : Colors.black38;
    final time = DateFormat('HH:mm').format(message.sentAt.toLocal());
    final replyData = _replyData();
    final bodyText = _messageBodyText(replyData);

    return _ReplySwipeWrapper(
      enabled: !message.isDeleted,
      onReply: onReply,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            margin: EdgeInsets.only(
              top: 2,
              bottom: 2,
              left: isMe ? 60 : 0,
              right: isMe ? 0 : 60,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (isGroup && !isMe) ...[
                  _buildSmallAvatar(message.senderImageUrl),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (isGroup && !isMe && message.senderName != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 2),
                          child: Text(
                            message.senderName!,
                            style: TextStyle(
                              fontFamily: 'SFPro',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (replyData != null && !message.isDeleted) ...[
                        _ReplyQuote(data: replyData, isDark: isDark),
                        const SizedBox(height: 6),
                      ],
                      // Content
                      if (message.isDeleted)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.block, size: 14, color: timeColor),
                            const SizedBox(width: 4),
                            Text(
                              'This message was deleted',
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                fontStyle: FontStyle.italic,
                                color: timeColor,
                              ),
                            ),
                          ],
                        )
                      else if (_isAudioMessage()) ...[
                        _VoiceNotePlayer(
                          mediaUrl: message.mediaUrl,
                          isDark: isDark,
                          isMe: isMe,
                        ),
                      ] else if (_pollData() != null) ...[
                        _InteractivePoll(
                          message: message,
                          currentUserId: currentUserId,
                          data: _pollData()!,
                          isDark: isDark,
                          isMe: isMe,
                        ),
                      ] else if (_locationPoint() != null) ...[
                        _LocationMessageCard(
                          point: _locationPoint()!,
                          isDark: isDark,
                          isMe: isMe,
                        ),
                      ] else if (message.messageType != 'text' &&
                          message.mediaUrl != null) ...[
                        _buildMediaContent(context),
                        if (bodyText.isNotEmpty &&
                            bodyText != message.mediaFileName)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              bodyText,
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                color: textColor,
                              ),
                            ),
                          ),
                      ] else
                        Text(
                          bodyText,
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            color: textColor,
                          ),
                        ),
                      const SizedBox(height: 4),
                      // Time + edited + read ticks
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.editedAt != null && !message.isDeleted)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                'edited',
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: timeColor,
                                ),
                              ),
                            ),
                          Text(
                            time,
                            style: TextStyle(
                              fontFamily: 'SFPro',
                              fontSize: 11,
                              color: timeColor,
                            ),
                          ),
                          // Double tick for sent messages
                          if (isMe && !message.isDeleted) ...[
                            const SizedBox(width: 3),
                            Icon(
                              Icons.done_all,
                              size: 16,
                              color: message.seenByAll
                                  ? const Color(0xFF53BDEB) // blue ticks
                                  : timeColor, // grey ticks
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Reactions
                if (message.reactions.isNotEmpty)
                  Transform.translate(
                    offset: const Offset(0, -4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B3A2D) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: _groupReactions().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              '${entry.key}${entry.value > 1 ? ' ${entry.value}' : ''}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ], // closes Column children
              ), // closes Column
            ), // closes Flexible
          ], // closes Row children
        ), // closes Row
      ), // closes Container
    ), // closes GestureDetector
  ), // closes Align
); // closes _ReplySwipeWrapper
  }

  Map<String, int> _groupReactions() {
    final map = <String, int>{};
    for (final r in message.reactions) {
      map[r.emoji] = (map[r.emoji] ?? 0) + 1;
    }
    return map;
  }

  Widget _buildSmallAvatar(String? imageUrl) {
    final resolved = ApiClient.resolveUrl(imageUrl);
    if (resolved != null && resolved.isNotEmpty) {
      return ClipOval(
        child: CachedImageWidget(
          imageUrl: resolved,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorWidget: Container(
            color: Colors.grey.shade400,
            child: const Icon(Icons.person, color: Colors.white, size: 16),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: Colors.grey.shade400,
      child: const Icon(Icons.person, color: Colors.white, size: 16),
    );
  }

  _ReplyData? _replyData() {
    final firstBreak = message.text.indexOf('\n');
    if (firstBreak <= 0) return null;
    final header = message.text.substring(0, firstBreak);
    if (!header.startsWith('[reply|') || !header.endsWith(']')) return null;
    final parts = header.substring(7, header.length - 1).split('|');
    if (parts.length < 2) return null;
    return _ReplyData(author: parts.first, snippet: parts.sublist(1).join('|'));
  }

  String _messageBodyText(_ReplyData? replyData) {
    if (replyData == null) return message.text;
    final firstBreak = message.text.indexOf('\n');
    if (firstBreak < 0 || firstBreak + 1 >= message.text.length) return '';
    return message.text.substring(firstBreak + 1);
  }

  Widget _buildMediaContent(BuildContext context) {
    final resolved = ApiClient.resolveUrl(message.mediaUrl);
    final type = _mediaType();

    if (type == _MediaKind.image && resolved != null) {
      return GestureDetector(
        onTap: () => _openMediaViewer(context, resolved, isVideo: false),
        child: _ChatImagePreview(url: resolved, fallback: _fileChip()),
      );
    }

    if (type == _MediaKind.video && resolved != null) {
      return GestureDetector(
        onTap: () => _openMediaViewer(context, resolved, isVideo: true),
        child: _VideoPreview(url: resolved, isDark: isDark),
      );
    }

    return GestureDetector(
      onTap: () => _openDocumentFile(context),
      child: _fileChip(),
    );
  }

  Future<void> _openDocumentFile(BuildContext context) async {
    final mediaPath = message.mediaUrl;
    if (mediaPath == null || mediaPath.isEmpty) return;

    final fileName = message.mediaFileName ?? 'document';
    
    await DocumentManager.viewDocument(
      context,
      downloadUrl: mediaPath,
      originalFileName: fileName,
    );
  }

  Widget _fileChip() {
    final type = _mediaType();
    final icon = type == _MediaKind.video
        ? Icons.videocam
        : type == _MediaKind.image
        ? Icons.image
        : type == _MediaKind.audio
        ? Icons.mic
        : Icons.insert_drive_file;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.green.shade700),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            message.mediaFileName ?? 'File',
            style: const TextStyle(
              fontFamily: 'SFPro',
              fontSize: 13,
              decoration: TextDecoration.underline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  _PollData? _pollData() {
    final lines = message.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length < 3) return null;
    final first = lines.first;
    final marker = first.contains('Poll:') ? 'Poll:' : null;
    if (marker == null) return null;
    final question = first
        .substring(first.indexOf(marker) + marker.length)
        .trim();
    final allowMultiple = lines.any(
      (line) => line.toLowerCase() == '[multiple answers]',
    );
    final options = lines
        .skip(1)
        .where((line) {
          final normalized = line.toLowerCase();
          return normalized != '[multiple answers]' &&
              normalized != '[single answer]';
        })
        .map((line) {
          return line.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '').trim();
        })
        .where((line) => line.isNotEmpty)
        .toList();
    if (question.isEmpty || options.length < 2) return null;
    return _PollData(
      question: question,
      options: options,
      allowMultipleAnswers: allowMultiple,
    );
  }

  bool _isAudioMessage() => _mediaType() == _MediaKind.audio;

  LocationPoint? _locationPoint() {
    final lat = message.locationLatitude;
    final lng = message.locationLongitude;
    if (lat == null || lng == null) return null;
    return LocationPoint(
      latitude: lat,
      longitude: lng,
      label: message.locationLabel?.trim().isNotEmpty == true
          ? message.locationLabel
          : message.text,
    );
  }

  _MediaKind _mediaType() {
    final rawType = message.messageType.toLowerCase();
    final fileName = (message.mediaFileName ?? message.mediaUrl ?? '')
        .toLowerCase();
    if (rawType.contains('image') ||
        RegExp(r'\.(png|jpe?g|gif|webp|bmp)$').hasMatch(fileName)) {
      return _MediaKind.image;
    }
    if (rawType.contains('video') ||
        RegExp(r'\.(mp4|mov|m4v|webm|avi|mkv)$').hasMatch(fileName)) {
      return _MediaKind.video;
    }
    if (rawType.contains('audio') ||
        rawType.contains('voice') ||
        RegExp(r'\.(m4a|aac|mp3|wav|ogg|opus)$').hasMatch(fileName)) {
      return _MediaKind.audio;
    }
    return _MediaKind.file;
  }

  void _openMediaViewer(
    BuildContext context,
    String url, {
    required bool isVideo,
  }) {
    Navigator.of(context).push(
      AppPageRoute(
        child: _MediaViewer(url: url, isVideo: isVideo),
      ),
    );
  }
}

enum _MediaKind { image, video, audio, file }

class _LocationMessageCard extends StatelessWidget {
  final LocationPoint point;
  final bool isDark;
  final bool isMe;

  const _LocationMessageCard({
    required this.point,
    required this.isDark,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OsmMapPreview(
            point: point,
            height: 150,
            onTap: () async {
              final url = 'https://maps.google.com/?q=${point.latitude},${point.longitude}';
              try {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  point.label?.trim().isNotEmpty == true
                      ? point.label!.trim()
                      : 'Shared location',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }
}

class _PollData {
  final String question;
  final List<String> options;
  final bool allowMultipleAnswers;

  const _PollData({
    required this.question,
    required this.options,
    this.allowMultipleAnswers = false,
  });
}

class _InteractivePoll extends StatefulWidget {
  final ChatMessage message;
  final String currentUserId;
  final _PollData data;
  final bool isDark;
  final bool isMe;

  const _InteractivePoll({
    required this.message,
    required this.currentUserId,
    required this.data,
    required this.isDark,
    required this.isMe,
  });

  @override
  State<_InteractivePoll> createState() => _InteractivePollState();
}

class _InteractivePollState extends State<_InteractivePoll> {
  static const _numberEmojis = ['1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟'];

  @override
  Widget build(BuildContext context) {
    final accent = widget.isMe
        ? const Color(0xFF1FA855)
        : Colors.green.shade700;
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final subText = widget.isDark ? Colors.white54 : Colors.black45;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll_rounded, size: 18, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.data.question,
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...widget.data.options.asMap().entries.map((entry) {
            final index = entry.key;
            final emoji = index < _numberEmojis.length ? _numberEmojis[index] : '❓';
            final voteCount = widget.message.reactions.where((r) => r.emoji == emoji).length;
            final isSelected = widget.message.reactions.any((r) => r.emoji == emoji && r.userId == widget.currentUserId);
            final totalVotes = widget.message.reactions.where((r) => _numberEmojis.contains(r.emoji)).length;
            final progress = totalVotes == 0 ? 0.0 : voteCount / totalVotes;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  context.read<ChatBloc>().add(
                    ToggleReaction(messageId: widget.message.messageId, emoji: emoji),
                  );
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        AnimatedContainer(
                          width: constraints.maxWidth * progress,
                          height: 42,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? accent
                                  : (widget.isDark
                                        ? Colors.white12
                                        : Colors.black12),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? accent
                                      : Colors.transparent,
                                  border: Border.all(color: accent, width: 1.5),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 14,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'SFPro',
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                voteCount == 0
                                    ? ''
                                    : '$voteCount',
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  fontSize: 12,
                                  color: subText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          }),
          Text(
            widget.message.reactions.isEmpty
                ? (widget.data.allowMultipleAnswers
                      ? 'Tap one or more answers'
                      : 'Tap to vote')
                : '${widget.message.reactions.where((r) => _numberEmojis.contains(r.emoji)).length} vote${widget.message.reactions.where((r) => _numberEmojis.contains(r.emoji)).length == 1 ? '' : 's'}',
            style: TextStyle(fontFamily: 'SFPro', fontSize: 11, color: subText),
          ),
        ],
      ),
    );
  }
}

class _ChatImagePreview extends StatefulWidget {
  final String url;
  final Widget fallback;

  const _ChatImagePreview({required this.url, required this.fallback});

  @override
  State<_ChatImagePreview> createState() => _ChatImagePreviewState();
}

class _ChatImagePreviewState extends State<_ChatImagePreview>
    with AutomaticKeepAliveClientMixin {
  late final ImageProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = NetworkImage(widget.url);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240, maxHeight: 300),
        child: Image(
          image: _provider,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          frameBuilder: (_, child, frame, __) {
            if (frame != null) return child;
            return const SizedBox(
              width: 120,
              height: 120,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
          errorBuilder: (_, __, ___) => widget.fallback,
        ),
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  final String url;
  final bool isDark;

  const _VideoPreview({required this.url, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        key: ValueKey(url),
        width: 240,
        height: 150,
        color: isDark ? Colors.black26 : Colors.black12,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.62),
                      Colors.black.withValues(alpha: 0.24),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaViewer extends StatelessWidget {
  final String url;
  final bool isVideo;

  const _MediaViewer({super.key, required this.url, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: isVideo
            ? AppVideoPlayer(
                url: url,
                autoPlay: true,
                showControls: true,
              )
            : InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: CachedImageWidget(imageUrl: url, fit: BoxFit.contain),
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// VOICE NOTE PLAYER
// ═══════════════════════════════════════════════════
class _VoiceNotePlayer extends StatefulWidget {
  final String? mediaUrl;
  final bool isDark;
  final bool isMe;

  const _VoiceNotePlayer({
    required this.mediaUrl,
    required this.isDark,
    required this.isMe,
  });

  @override
  State<_VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<_VoiceNotePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.onDurationChanged.listen((dur) {
      if (mounted && dur.inMilliseconds > 0) {
        setState(() => _duration = dur);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      final resolved = ApiClient.resolveUrl(widget.mediaUrl);
      if (resolved == null) return;
      if (_position.inMilliseconds > 0) {
        await _player.resume();
      } else {
        await _player.play(UrlSource(resolved));
      }
    }
  }

  String _formatDur(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;
    final accentColor = widget.isMe ? Colors.white : Colors.green.shade700;
    final trackColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.3)
        : Colors.green.shade700.withValues(alpha: 0.3);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 190, maxWidth: 240),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: accentColor,
              size: 36,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0).toDouble(),
                      backgroundColor: trackColor,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isPlaying ? _formatDur(_position) : _formatDur(_duration),
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 11,
                    color: widget.isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.mic, size: 16, color: accentColor.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// MEDIA CAPTION RESULT
// ═══════════════════════════════════════════════════
class _MediaCaptionResult {
  final List<XFile> files;
  final String? caption;

  const _MediaCaptionResult({required this.files, this.caption});
}

// ═══════════════════════════════════════════════════
// MEDIA CAPTION / CONFIRMATION PAGE (WhatsApp style)
// ═══════════════════════════════════════════════════
class _MediaCaptionPage extends StatefulWidget {
  final List<XFile> files;
  final bool isVideo;

  const _MediaCaptionPage({required this.files, this.isVideo = false});

  @override
  State<_MediaCaptionPage> createState() => _MediaCaptionPageState();
}

class _MediaCaptionPageState extends State<_MediaCaptionPage> {
  final TextEditingController _captionController = TextEditingController();
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool _isVideoFile(String path) {
    final lower = path.toLowerCase();
    return RegExp(r'\.(mp4|mov|m4v|webm|avi|mkv)$').hasMatch(lower);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF020806) : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF0A1F15)
            : Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${widget.files.length} ${widget.files.length == 1 ? 'item' : 'items'} selected',
          style: const TextStyle(fontFamily: 'SFPro', fontSize: 16),
        ),
        actions: [
          if (widget.files.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${_currentPage + 1}/${widget.files.length}',
                  style: const TextStyle(
                    fontFamily: 'SFPro',
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Media preview
          Expanded(
            child: widget.files.length == 1
                ? _buildSinglePreview(widget.files.first)
                : PageView.builder(
                    controller: _pageController,
                    itemCount: widget.files.length,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemBuilder: (_, index) =>
                        _buildSinglePreview(widget.files[index]),
                  ),
          ),
          // Page indicator for multiple files
          if (widget.files.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.files.length, (i) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _currentPage
                          ? Colors.green.shade700
                          : Colors.white30,
                    ),
                  );
                }),
              ),
            ),
          // Caption input + send
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            color: isDark ? const Color(0xFF0A1F15) : Colors.grey.shade900,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1B3A2D)
                            : Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(
                          fontFamily: 'SFPro',
                          color: Colors.white,
                        ),
                        maxLines: 3,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(
                            fontFamily: 'SFPro',
                            color: Colors.white38,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () {
                        final caption = _captionController.text.trim();
                        Navigator.pop(
                          context,
                          _MediaCaptionResult(
                            files: widget.files,
                            caption: caption.isEmpty ? null : caption,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSinglePreview(XFile file) {
    if (_isVideoFile(file.path) || widget.isVideo) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Image.file(
              File(file.path),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.videocam, color: Colors.white54, size: 64),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
          ),
        ],
      );
    }
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: Image.file(
          File(file.path),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, color: Colors.white54, size: 64),
        ),
      ),
    );
  }
}


