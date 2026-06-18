class PlayerStat {
  final String title;
  final String lastGame;
  final String cumulative;

  const PlayerStat({
    required this.title,
    required this.lastGame,
    required this.cumulative,
  });
}

class FitnessRecord {
  final String label;
  final String value;

  const FitnessRecord({required this.label, required this.value});
}

class MedicalRecord {
  final String title;
  final String status;
  final String? startDate;
  final String? endDate;

  const MedicalRecord({
    required this.title,
    this.status = "",
    this.startDate,
    this.endDate,
  });
}
