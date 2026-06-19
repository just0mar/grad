class GameHistory {
  final String? eventId;
  final String? clubId;
  final String? teamId;
  final String opponent;
  final String date;
  final int ourScore;
  final int theirScore;
  final List<Map<String, String>> stats;
  final List<Map<String, String>> videos; // {title, url}

  GameHistory({
    this.eventId,
    this.clubId,
    this.teamId,
    required this.opponent,
    required this.date,
    required this.ourScore,
    required this.theirScore,
    required this.stats,
    required this.videos,
  });
}