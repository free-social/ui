class WalletBalanceModel {
  final String id;
  final double balance;
  final String userId;

  WalletBalanceModel({
    required this.id,
    required this.balance,
    required this.userId,
  });

  factory WalletBalanceModel.fromJson(Map<String, dynamic> json) {
    return WalletBalanceModel(
      id: json['_id'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      userId: json['user'] ?? '',
    );
  }
}
