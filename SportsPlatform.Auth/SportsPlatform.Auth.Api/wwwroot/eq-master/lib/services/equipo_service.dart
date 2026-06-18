import 'api_client.dart';

/// Talks to the "Ask Equipo" chatbot through the app's own backend proxy
/// (POST /chatbot/ask), which forwards to the chatbot/prediction microservice.
/// We never call the microservice directly — the proxy reuses the user's JWT
/// and keeps the microservice port internal.
class EquipoService {
  final ApiClient _api = ApiClient.instance;

  /// Ask a question scoped to a team. Pass the active team id (== project id on
  /// the microservice) and, ideally, the active club id for the scope check.
  /// [sessionId] keeps a conversation threaded across turns; pass back what the
  /// previous answer returned, or null for a fresh session.
  Future<EquipoAnswer> ask({
    required String teamId,
    String? clubId,
    required String question,
    String? sessionId,
  }) async {
    final json = await _api.post('/chatbot/ask', body: {
      'teamId': teamId,
      if (clubId != null && clubId.isNotEmpty) 'clubId': clubId,
      'question': question,
      if (sessionId != null && sessionId.isNotEmpty) 'sessionId': sessionId,
    });
    return EquipoAnswer.fromJson(Map<String, dynamic>.from(json as Map));
  }
}

/// One answer from the chatbot. Mirrors the microservice AskResponse but only
/// surfaces the fields the chat UI needs; everything else is ignored defensively.
class EquipoAnswer {
  final String answer;
  final String sessionId;
  final String route;
  final String type;

  const EquipoAnswer({
    required this.answer,
    required this.sessionId,
    required this.route,
    required this.type,
  });

  factory EquipoAnswer.fromJson(Map<String, dynamic> json) {
    return EquipoAnswer(
      answer: (json['answer'] ?? '').toString(),
      sessionId: (json['session_id'] ?? '').toString(),
      route: (json['route'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
    );
  }
}
