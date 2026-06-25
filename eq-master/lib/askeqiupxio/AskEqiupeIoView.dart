import 'package:flutter/material.dart';
import '../appbar/CustomAppBar.dart';
import '../core/app_background.dart';
import '../core/animated_button.dart';
import '../core/design_tokens.dart';
import '../services/api_client.dart';
import '../services/equipo_service.dart';
import '../core/app_localizations.dart';

class AskEquipoView extends StatefulWidget {
  const AskEquipoView({super.key});

  @override
  State<AskEquipoView> createState() => _AskEquipoViewState();
}

class _AskEquipoViewState extends State<AskEquipoView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final EquipoService _equipo = EquipoService();

  // Kept across turns so the chatbot threads the conversation.
  String? _sessionId;
  bool _sending = false;
  late final List<Map<String, dynamic>> _messages;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final t = AppLocalizations.of(context);
      _messages = [
        {"text": t.askEqWelcome, "fromMe": false},
        {"text": t.askEqPrompt, "fromMe": false},
      ];
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add({"text": text, "fromMe": true});
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final t = AppLocalizations.of(context);
      final teamId = await ApiClient.instance.getActiveTeam();
      if (teamId == null || teamId.isEmpty) {
        _addBot(t.askEqPickTeam);
        return;
      }
      final clubId = await ApiClient.instance.getActiveClub();

      final answer = await _equipo.ask(
        teamId: teamId,
        clubId: clubId,
        question: text,
        sessionId: _sessionId,
      );

      _sessionId = answer.sessionId.isNotEmpty ? answer.sessionId : _sessionId;
      _addBot(answer.answer.isNotEmpty
          ? answer.answer
          : t.askEqNoAnswer);
    } catch (e) {
      if (!mounted) return;
      _addBot(friendlyErrorText(e, fallback: AppLocalizations.of(context).askEqError));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _addBot(String text) {
    if (!mounted) return;
    setState(() => _messages.add({"text": text, "fromMe": false}));
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardH = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: CustomAppBar(title: AppLocalizations.of(context).askEqTitle, showTeamSwitcher: true),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final fromMe = message["fromMe"] as bool;
                    return Row(
                      mainAxisAlignment: fromMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (!fromMe)
                          const CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.smart_toy, color: Colors.white),
                          ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: fromMe
                                  ? Colors.green
                                  : isDark
                                  ? const Color(0xFF1B3A2D)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(2, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              message["text"],
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                color: fromMe
                                    ? Colors.white
                                    : isDark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (fromMe)
                          const CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (_sending)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      AppLocalizations.of(context).askEqThinking,
                      style: const TextStyle(
                        fontFamily: 'SFPro',
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: keyboardH),
                child: _MessageInput(
                  controller: _controller,
                  onSend: _sendMessage,
                  sending: _sending,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;

  const _MessageInput({
    required this.controller,
    required this.onSend,
    this.sending = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: controller,
        enabled: !sending,
        textInputAction: TextInputAction.send,
        onSubmitted: sending ? null : (_) => onSend(),
        style: TextStyle(
          fontFamily: 'SFPro',
          color: isDark ? Colors.white : Colors.black,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: isDark ? const Color(0xFF1B3A2D) : Colors.white,
          labelText: AppLocalizations.of(context).askEqTypeMsg,
          labelStyle: TextStyle(
            fontFamily: 'SFPro',
            color: isDark ? Colors.white60 : Colors.black54,
          ),
          hintStyle: const TextStyle(fontFamily: 'SFPro'),
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary),
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: isDark ? Colors.white24 : AppColors.primary,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(28)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary, width: 2),
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: CircleAvatar(
                  backgroundColor: sending ? Colors.grey : Colors.green,
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: onSend,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
