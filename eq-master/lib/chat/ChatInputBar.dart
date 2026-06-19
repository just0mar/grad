import 'package:flutter/material.dart';
import '../core/design_tokens.dart';

class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;

  const ChatInputBar({super.key, required this.onSend});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _controller,
        style: TextStyle(
          fontFamily: 'SFPro',
          color: isDark ? Colors.white : Colors.black,
        ),
        onSubmitted: (_) => _handleSend(),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.inputFill(context),
          labelText: 'Type a message',
          labelStyle: TextStyle(
            fontFamily: 'SFPro',
            color: isDark ? Colors.white60 : Colors.black54,
          ),
          // Strokeless rounded input to match the rest of the app.
          border: const OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.all(Radius.circular(30)),
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.all(Radius.circular(30)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.all(Radius.circular(30)),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file, color: AppColors.primary),
                onPressed: () {},
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: CircleAvatar(
                  backgroundColor: Colors.green,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _handleSend,
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
