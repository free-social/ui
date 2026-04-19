import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/wallet_service.dart';
import '../services/expense_service.dart';
import '../services/local_cache_service.dart';

class WalletProvider with ChangeNotifier {
  final WalletService _walletService;
  final ExpenseService _expenseService;
  final LocalCacheService _cacheService;

  WalletProvider({WalletService? walletService, ExpenseService? expenseService})
    : _walletService = walletService ?? WalletService(),
      _expenseService = expenseService ?? ExpenseService(),
      _cacheService = LocalCacheService();

  // State
  WalletData? _walletData;
  double _lastMonthExpense = 0.0;
  bool _isLoading = false;
  String? _error;

  // Getters
  WalletData? get walletData => _walletData;
  double get lastMonthExpense => _lastMonthExpense;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch all wallet data
  Future<void> fetchWalletData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId != null && userId.isNotEmpty) {
        final cachedWalletData = await _cacheService.getWalletData(userId);
        if (cachedWalletData != null) {
          _walletData = cachedWalletData;
          _lastMonthExpense = cachedWalletData.lastMonthExpense;
          _isLoading = false;
          notifyListeners();
        }
      }

      // Calculate previous month
      DateTime now = DateTime.now();
      int prevMonth = now.month - 1;
      int prevYear = now.year;

      if (prevMonth == 0) {
        prevMonth = 12;
        prevYear = now.year - 1;
      }

      // Fetch wallet data and last month expense
      final results = await Future.wait([
        _walletService.fetchWalletData(),
        _expenseService.getMonthlyExpenseTotal(prevMonth, prevYear),
      ]);

      _walletData = results[0] as WalletData;
      _lastMonthExpense = results[1] as double;

      if (userId != null && userId.isNotEmpty && _walletData != null) {
        final freshWalletData = WalletData(
          user: _walletData!.user,
          transactions: _walletData!.transactions,
          walletBalance: _walletData!.walletBalance,
          lastMonthExpense: _lastMonthExpense,
        );
        await _cacheService.saveWalletData(userId, freshWalletData);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching wallet data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Top up wallet (positive amount) or deduct (negative amount)
  Future<void> topUpWallet(double amount) async {
    try {
      await _walletService.topUpWallet(amount);
      await fetchWalletData(); // Refresh data
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Update wallet balance to a specific amount
  Future<void> updateWalletBalance(double newBalance) async {
    try {
      await _walletService.updateWalletBalance(newBalance);
      await fetchWalletData(); // Refresh data
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Refresh all data
  Future<void> refreshData() async {
    await fetchWalletData();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
