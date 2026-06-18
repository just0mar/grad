import 'package:flutter/material.dart';

import 'ChatModel.dart';

class ChatViewModel extends ChangeNotifier {
  final List<ChatMessage> _messages = [];

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void sendMessage(String text, {bool fromMe = true}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _messages.add(ChatMessage(text: trimmed, fromMe: fromMe));
    notifyListeners();
  }

  void simulateReply(String text) {
    Future.delayed(const Duration(seconds: 2), () {
      _messages.add(ChatMessage(text: text, fromMe: false));
      notifyListeners();
    });
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  void deleteMessage(int index) {
    if (index < 0 || index >= _messages.length) {
      return;
    }
    _messages.removeAt(index);
    notifyListeners();
  }

  void editMessage(int index, String newText) {
    if (index < 0 || index >= _messages.length) {
      return;
    }
    _messages[index] = ChatMessage(
      text: newText.trim(),
      fromMe: _messages[index].fromMe,
    );
    notifyListeners();
  }
}
