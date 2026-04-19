import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../services/expense_service.dart';
import '../services/local_cache_service.dart';

class ExpenseProvider with ChangeNotifier {
  final ExpenseService _expenseService;
  final LocalCacheService _cacheService;
  ExpenseProvider({
    ExpenseService? expenseService,
    LocalCacheService? cacheService,
  }) : _expenseService = expenseService ?? ExpenseService(),
       _cacheService = cacheService ?? LocalCacheService();

  LocalCacheService get cacheService => _cacheService;

  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  bool _isStatsLoading = false;
  dynamic _monthlySummary;
  dynamic _dailySummary;

  // Track filter state
  int _currentPage = 1;
  int _currentLimit = 100;
  String? _currentCategory;

  // Track Sort State
  String _currentSortBy = 'date';
  String _currentSortOrder = 'desc';

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  List<TransactionModel> get transactions => _transactions;
  dynamic get monthlySummary => _monthlySummary;
  dynamic get dailySummary => _dailySummary;
  bool get isLoading => _isLoading;
  bool get isStatsLoading => _isStatsLoading;

  int get currentPage => _currentPage;
  String? get currentCategory => _currentCategory;

  Future<void> fetchTransactions({
    int? page,
    int? limit,
    String? category,
    String? sortBy,
    String? sortOrder,
    bool forceRefresh = false,
  }) async {
    // If refreshing or loading page 1, show full loading spinner.
    // If loading page 2+, we usually show a smaller spinner at bottom (handled in UI).
    if (page == 1 || page == null) _isLoading = true;

    if (forceRefresh) notifyListeners();

    if (page != null) _currentPage = page;
    if (limit != null) _currentLimit = limit;

    if (category != null) {
      _currentCategory = (category == 'All') ? null : category.toLowerCase();
    }
    if (sortBy != null) _currentSortBy = sortBy;
    if (sortOrder != null) _currentSortOrder = sortOrder;

    try {
      final userId = await _getUserId();
      if (userId != null && userId.isNotEmpty && _currentPage == 1) {
        final cachedTransactions = await _cacheService.getTransactions(
          userId,
          page: _currentPage,
          limit: _currentLimit,
          category: _currentCategory,
          sortBy: _currentSortBy,
          sortOrder: _currentSortOrder,
        );
        if (cachedTransactions != null && cachedTransactions.isNotEmpty) {
          _transactions = cachedTransactions;
          _isLoading = false;
          notifyListeners();
        }
      }

      final newData = await _expenseService.getAllTransactions(
        page: _currentPage,
        limit: _currentLimit,
        category: _currentCategory,
        sortBy: _currentSortBy,
        sortOrder: _currentSortOrder,
      );

      // PAGINATION LOGIC:
      if (_currentPage == 1) {
        _transactions = newData; // Replace list (New Filter or Refresh)
      } else {
        _transactions.addAll(newData); // Append to list (Load More)
      }

      if (userId != null && userId.isNotEmpty) {
        await _cacheService.saveTransactions(
          userId,
          _transactions,
          page: _currentPage,
          limit: _currentLimit,
          category: _currentCategory,
          sortBy: _currentSortBy,
          sortOrder: _currentSortOrder,
        );
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearFilters() {
    _currentCategory = null;
    _currentPage = 1;
    _currentSortBy = 'date';
    fetchTransactions(page: 1, category: 'All');
  }

  // Add Transaction
  Future<void> addTransaction(
    double amount,
    String category,
    String desc,
    DateTime date,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final newTransaction = TransactionModel(
        id: '',
        amount: amount,
        category: category,
        description: desc,
        date: date,
      );
      await _expenseService.createTransaction(newTransaction);
      final userId = await _getUserId();
      if (userId != null && userId.isNotEmpty) {
        await _cacheService.clearTransactionCaches(userId);
      }
      await fetchTransactions();
    } catch (e) {
      debugPrint('Error adding transaction: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 3. Update Transaction
  Future<void> updateTransaction(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _expenseService.updateTransaction(id, updates);
      final userId = await _getUserId();
      if (userId != null && userId.isNotEmpty) {
        await _cacheService.clearTransactionCaches(userId);
      }
      await fetchTransactions();
    } catch (e) {
      debugPrint('Error updating transaction: $e');
      rethrow;
    }
  }

  // 4. Delete Transaction
  Future<void> deleteTransaction(String id) async {
    try {
      await _expenseService.deleteTransaction(id);
      final userId = await _getUserId();
      if (userId != null && userId.isNotEmpty) {
        await _cacheService.clearTransactionCaches(userId);
      }
      _transactions.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      rethrow;
    }
  }

  // 5. Monthly Expenses
  Future<void> fetchMonthlyExpenses(int month, int year) async {
    _isStatsLoading = true;
    notifyListeners();
    try {
      final userId = await _getUserId();
      if (userId != null && userId.isNotEmpty) {
        final cachedSummary = await _cacheService.getMonthlySummary(
          userId,
          month,
          year,
        );
        if (cachedSummary != null) {
          _monthlySummary = cachedSummary;
          _isStatsLoading = false;
          notifyListeners();
        }
      }

      _monthlySummary = await _expenseService.getMonthlyExpenses(month, year);
      if (userId != null && userId.isNotEmpty && _monthlySummary != null) {
        await _cacheService.saveMonthlySummary(userId, month, year, _monthlySummary);
      }
    } catch (e) {
      debugPrint('Error fetching monthly report: $e');
    } finally {
      _isStatsLoading = false;
      notifyListeners();
    }
  }

  // 6. Daily Expenses
  Future<void> fetchDailyExpenses([DateTime? date]) async {
    _isStatsLoading = true;
    notifyListeners();
    try {
      final userId = await _getUserId();
      if (userId != null && userId.isNotEmpty) {
        final cachedSummary = await _cacheService.getDailySummary(userId);
        if (cachedSummary != null) {
          _dailySummary = cachedSummary;
          _isStatsLoading = false;
          notifyListeners();
        }
      }

      _dailySummary = await _expenseService.getDailyExpenses(date: date);
      if (userId != null && userId.isNotEmpty && _dailySummary != null) {
        await _cacheService.saveDailySummary(userId, _dailySummary);
      }
    } catch (e) {
      debugPrint('Error fetching daily report: $e');
    } finally {
      _isStatsLoading = false;
      notifyListeners();
    }
  }
}
