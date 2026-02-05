import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/expense_service.dart';

class ExpenseProvider with ChangeNotifier {
  final ExpenseService _expenseService = ExpenseService();

  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  dynamic _monthlySummary;
  dynamic _dailySummary;

  // Track filter state
  int _currentPage = 1;
  int _currentLimit = 100;
  String? _currentCategory;

  // ✅ NEW: Track Sort State
  String _currentSortBy = 'date';
  String _currentSortOrder = 'desc';

  List<TransactionModel> get transactions => _transactions;
  dynamic get monthlySummary => _monthlySummary;
  dynamic get dailySummary => _dailySummary;
  bool get isLoading => _isLoading;

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
      final newData = await _expenseService.getAllTransactions(
        page: _currentPage,
        limit: _currentLimit,
        category: _currentCategory,
        sortBy: _currentSortBy,
        sortOrder: _currentSortOrder,
      );

      // ✅ PAGINATION LOGIC:
      if (_currentPage == 1) {
        _transactions = newData; // Replace list (New Filter or Refresh)
      } else {
        _transactions.addAll(newData); // Append to list (Load More)
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

  // ... (Keep addTransaction, updateTransaction, deleteTransaction, fetchMonthly, fetchDaily exactly as they were) ...
  // 2. Add Transaction
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
      _transactions.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      rethrow;
    }
  }

  // 5. Monthly Expenses
  Future<void> fetchMonthlyExpenses(int month, int year) async {
    try {
      _monthlySummary = await _expenseService.getMonthlyExpenses(month, year);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching monthly report: $e');
    }
  }

  // 6. Daily Expenses
  Future<void> fetchDailyExpenses([DateTime? date]) async {
    try {
      _dailySummary = await _expenseService.getDailyExpenses(date: date);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching daily report: $e');
    }
  }
}
