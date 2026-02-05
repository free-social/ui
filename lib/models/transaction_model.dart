class TransactionModel {
  final String id;
  final double amount;
  final String category;
  final String description;
  final DateTime date;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
  });

  // Handles MongoDB "_id" or standard "id"
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['_id'] ?? json['id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      category: json['category'] ?? 'General',
      description: json['description'] ?? '',
      // ✅ FIX: Read 'date' first, then 'createdAt', then fallback to now()
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : (json['createdAt'] != null 
              ? DateTime.parse(json['createdAt']) 
              : DateTime.now()), 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'category': category,
      'description': description,
      // ✅ FIX: Send the specific date to backend
      'date': date.toIso8601String(), 
    };
  }
}