import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../models/wallet_balance_model.dart';
import 'wallet_service.dart';

class LocalCacheService {
  static const _userProfilePrefix = 'cache:user:profile:';
  static const _walletDataPrefix = 'cache:wallet:data:';
  static const _transactionsPrefix = 'cache:transactions:list:';
  static const _dailySummaryPrefix = 'cache:transactions:daily:';
  static const _monthlySummaryPrefix = 'cache:transactions:monthly:';

  Future<void> saveUserProfile(String userId, User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_userProfilePrefix$userId',
      jsonEncode(user.toJson()),
    );
  }

  Future<User?> getUserProfile(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_userProfilePrefix$userId');
    if (raw == null || raw.isEmpty) return null;

    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUserProfile(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_userProfilePrefix$userId');
  }

  Future<void> saveWalletData(String userId, WalletData walletData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_walletDataPrefix$userId',
      jsonEncode({
        'user': walletData.user.toJson(),
        'transactions': walletData.transactions.map((t) => t.toJson()).toList(),
        'walletBalance': walletData.walletBalance.toJson(),
        'lastMonthExpense': walletData.lastMonthExpense,
      }),
    );
  }

  Future<WalletData?> getWalletData(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_walletDataPrefix$userId');
    if (raw == null || raw.isEmpty) return null;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return WalletData(
        user: User.fromJson(data['user'] as Map<String, dynamic>),
        transactions:
            ((data['transactions'] as List<dynamic>?) ?? const [])
                .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
                .toList(),
        walletBalance: WalletBalanceModel.fromJson(
          data['walletBalance'] as Map<String, dynamic>,
        ),
        lastMonthExpense: (data['lastMonthExpense'] ?? 0).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearWalletData(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_walletDataPrefix$userId');
  }

  Future<void> saveTransactions(
    String userId,
    List<TransactionModel> transactions, {
    required int page,
    required int limit,
    String? category,
    required String sortBy,
    required String sortOrder,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _transactionsKey(
        userId,
        page: page,
        limit: limit,
        category: category,
        sortBy: sortBy,
        sortOrder: sortOrder,
      ),
      jsonEncode(transactions.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<TransactionModel>?> getTransactions(
    String userId, {
    required int page,
    required int limit,
    String? category,
    required String sortBy,
    required String sortOrder,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      _transactionsKey(
        userId,
        page: page,
        limit: limit,
        category: category,
        sortBy: sortBy,
        sortOrder: sortOrder,
      ),
    );
    if (raw == null || raw.isEmpty) return null;

    try {
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDailySummary(String userId, dynamic summary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_dailySummaryPrefix$userId',
      jsonEncode(summary),
    );
  }

  Future<dynamic> getDailySummary(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_dailySummaryPrefix$userId');
    if (raw == null || raw.isEmpty) return null;

    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMonthlySummary(String userId, int month, int year, dynamic summary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_monthlySummaryPrefix$userId:$year:$month',
      jsonEncode(summary),
    );
  }

  Future<dynamic> getMonthlySummary(String userId, int month, int year) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_monthlySummaryPrefix$userId:$year:$month');
    if (raw == null || raw.isEmpty) return null;

    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearTransactionCaches(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
      (key) =>
          key.startsWith('$_transactionsPrefix$userId:') ||
          key.startsWith('$_dailySummaryPrefix$userId') ||
          key.startsWith('$_monthlySummaryPrefix$userId:') ||
          key.startsWith('$_walletDataPrefix$userId'),
    );

    for (final key in keys.toList()) {
      await prefs.remove(key);
    }
  }

  String _transactionsKey(
    String userId, {
    required int page,
    required int limit,
    String? category,
    required String sortBy,
    required String sortOrder,
  }) {
    return [
      '$_transactionsPrefix$userId',
      'page:$page',
      'limit:$limit',
      'category:${category ?? "all"}',
      'sortBy:$sortBy',
      'sortOrder:$sortOrder',
    ].join(':');
  }
}
