import '../models/transaction_model.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';

class ExpenseService {
  final ApiService _apiService;

  // Constructor Injection
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
      // Expense form submits a positive amount. Use absolute value to support
      // both positive/negative payload conventions safely.
      final currentBalance = await _fetchCurrentBalance();
      final expenseAmount = transaction.amount.abs();

      if (expenseAmount > currentBalance) {
        throw Exception(
          'Insufficient balance. Current balance: \$${currentBalance.toStringAsFixed(2)}',
        );
      }

      final response = await _apiService.client.post(
        '/transactions',
        data: transaction.toJson(),
      );

      return TransactionModel.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(
        _extractApiErrorMessage(e, fallback: 'Failed to create transaction'),
      );
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Failed to create transaction: $e');
    }
  }

  Future<double> _fetchCurrentBalance() async {
    final response = await _apiService.client.get('/wallet');
    final data = response.data;

    if (data is Map<String, dynamic>) {
      final balance = data['balance'];
      if (balance is num) return balance.toDouble();
      if (balance is String) return double.tryParse(balance) ?? 0.0;
    }

    return 0.0;
  }

  String _extractApiErrorMessage(DioException e, {required String fallback}) {
    final data = e.response?.data;

    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) return message;

      final error = data['error'];
      if (error is String && error.trim().isNotEmpty) return error;

      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail;

      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is String && first.trim().isNotEmpty) return first;
        if (first is Map<String, dynamic>) {
          final firstMessage = first['message'];
          if (firstMessage is String && firstMessage.trim().isNotEmpty) {
            return firstMessage;
          }
        }
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    return fallback;
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

  // Get monthly expense total from backend (already calculated)
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
      return 0.0;
    }
  }

  // Get daily expense total from backend (already calculated)
  Future<double> getDailyTotal({DateTime? date}) async {
    try {
      final dailyData = await getDailyExpenses(date: date);

      // Extract totalSpent from backend response
      if (dailyData is Map && dailyData.containsKey('data')) {
        final data = dailyData['data'];
        final totalSpent = (data['totalSpent'] as num?)?.toDouble() ?? 0.0;
        return totalSpent.abs();
      }

      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }
}
