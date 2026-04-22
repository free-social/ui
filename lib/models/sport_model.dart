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
    return SportModel(
      id: json['_id'] ?? json['id'] ?? '',
      length: (json['length'] ?? 0).toDouble(),
      category: json['category'] ?? 'jogging',
      note: json['note'],
      duration: json['duration'] ?? 0,
      date: json['date'] != null
          ? DateTime.parse(json['date']).toLocal()
          : (json['createdAt'] != null
                ? DateTime.parse(json['createdAt']).toLocal()
                : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'length': length,
      'category': category,
      if (note != null) 'note': note,
      'duration': duration,
      'date': date.toUtc().toIso8601String(),
    };
  }
}
