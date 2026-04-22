class SportModel {
  final String id;
  final double length;
  final String category;
  final String? note;
  final int duration;
  final DateTime date;

  SportModel({
    required this.id,
    required this.length,
    required this.category,
    this.note,
    required this.duration,
    required this.date,
  });

  factory SportModel.fromJson(Map<String, dynamic> json) {
    final rawLength = json['length'];
    final rawDuration = json['duration'];

    return SportModel(
      id: json['_id'] ?? json['id'] ?? '',
      length: rawLength is num
          ? rawLength.toDouble()
          : double.tryParse(rawLength?.toString() ?? '') ?? 0.0,
      category: json['category'] ?? 'jogging',
      note: json['note'],
      duration: rawDuration is num
          ? rawDuration.toInt()
          : int.tryParse(rawDuration?.toString() ?? '') ?? 0,
      date: json['date'] != null
          ? DateTime.parse(json['date']).toLocal()
          : (json['createdAt'] != null
                ? DateTime.parse(json['createdAt']).toLocal()
                : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'length': length,
      'category': category,
      if (note != null) 'note': note,
      'duration': duration,
      'date': date.toUtc().toIso8601String(),
    };
  }
}
