import '../models/transaction_model.dart';
import 'api_service.dart';
import 'wallet_service.dart';

class ExpenseService {
  // final ApiService _apiService = ApiService();
  final ApiService _apiService;

  // ✅ Constructor Injection
  ExpenseService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  // 1. GET ALL (with Pagination & Filters)
  Future<List<TransactionModel>> getAllTransactions({
    int page = 1,
    int limit = 10,
    String? category,
    String sortBy = 'date',
    String sortOrder = 'desc',
  }) async {
    try {
      final response = await _apiService.client.get(
        '/transactions',
        queryParameters: {
          'page': page,
          'limit': limit,
          'sortBy': sortBy,
          'sortOrder': sortOrder,
          if (category != null) 'category': category,
        },
      );

      // Handle Mongoose Pagination Structure (docs vs data)
      List<dynamic> data;
      if (response.data is Map && response.data.containsKey('docs')) {
        data = response.data['docs'];
      } else if (response.data is List) {
        data = response.data;
      } else {
        data = [];
      }

      return data.map((json) => TransactionModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load transactions: $e');
    }
  }

  // 2. GET MONTHLY
  Future<dynamic> getMonthlyExpenses(int month, int year) async {
    try {
      final response = await _apiService.client.get(
        '/transactions/monthly',
        queryParameters: {'month': month, 'year': year},
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to load monthly expenses: $e');
    }
  }

  // 3. GET DAILY
  Future<dynamic> getDailyExpenses({DateTime? date}) async {
    try {
      // If date is provided, format it. Otherwise, send nothing (backend assumes today)
      String? formattedDate;
      if (date != null) {
        formattedDate =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      }

      final response = await _apiService.client.get(
        '/transactions/daily',
        queryParameters: formattedDate != null ? {'date': formattedDate} : null,
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to load daily expenses: $e');
    }
  }

  // 4. CREATE
  Future<TransactionModel> createTransaction(
    TransactionModel transaction,
  ) async {
    try {
      // Check wallet balance BEFORE creating expense (negative amount)
      if (transaction.amount < 0) {
        final walletService = WalletService();
        final walletData = await walletService.fetchWalletData();
        final currentBalance = walletData.walletBalance.balance;

        // Expense amount is negative, so we check if absolute value exceeds balance
        if (transaction.amount.abs() > currentBalance) {
          throw Exception(
            'Insufficient balance. Current balance: \$${currentBalance.toStringAsFixed(2)}',
          );
        }
      }

      // ✅ IMPROVED: Use the model's toJson() since we fixed it to include 'date'
      final response = await _apiService.client.post(
        '/transactions',
        data: transaction.toJson(),
      );

      // Return the created object from server (useful for getting the real ID)
      return TransactionModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create transaction: $e');
    }
  }

  // 5. UPDATE
  Future<void> updateTransaction(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _apiService.client.put('/transactions/$id', data: updates);
    } catch (e) {
      throw Exception('Failed to update transaction: $e');
    }
  }

  // 6. GET SINGLE
  Future<TransactionModel> getTransaction(String id) async {
    try {
      final response = await _apiService.client.get('/transactions/$id');
      return TransactionModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to load transaction: $e');
    }
  }

  // 7. DELETE
  Future<void> deleteTransaction(String id) async {
    try {
      await _apiService.client.delete('/transactions/$id');
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }
  // ... (កូដចាស់) ...

  // ✅ Get monthly expense total from backend (already calculated)
  Future<double> getMonthlyExpenseTotal(int month, int year) async {
    try {
      final response = await _apiService.client.get(
        '/transactions/monthly',
        queryParameters: {'month': month, 'year': year},
      );

      // Extract totalSpent from backend response
      final responseData = response.data;

      if (responseData == null || responseData['data'] == null) {
        return 0.0;
      }

      final data = responseData['data'];
      final totalSpent = (data['totalSpent'] as num?)?.toDouble() ?? 0.0;

      return totalSpent.abs(); // Return positive value for display
    } catch (e) {
      // print("Error fetching monthly expense: $e");
      return 0.0;
    }
  }

  // ✅ Get daily expense total from backend (already calculated)
  Future<double> getDailyTotal({DateTime? date}) async {
    try {
      final dailyData = await getDailyExpenses(date: date);

      // Extract totalSpent from backend response
      if (dailyData is Map && dailyData.containsKey('data')) {
        final data = dailyData['data'];
        final totalSpent = (data['totalSpent'] as num?)?.toDouble() ?? 0.0;
        return totalSpent.abs(); // Return positive value for display
      }

      return 0.0;
    } catch (e) {
      print("Error calculating daily total: $e");
      return 0.0;
    }
  }
}
