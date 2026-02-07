import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_balance_model.dart'; // ✅ Import ថ្មី
import 'auth_service.dart';
import 'expense_service.dart';
import 'api_service.dart'; // ✅ Import ApiService

// Class សម្រាប់វេចខ្ចប់ទិន្នន័យ
class WalletData {
  final User user;
  final List<TransactionModel> transactions;
  final WalletBalanceModel walletBalance; // ✅ ថែម field នេះ

  WalletData({
    required this.user,
    required this.transactions,
    required this.walletBalance, // ✅
  });
}

class WalletService {
  final AuthService _authService = AuthService();
  final ExpenseService _expenseService = ExpenseService();
  final ApiService _apiService = ApiService(); // ✅ ហៅ API Service មកប្រើ

  Future<WalletData> fetchWalletData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) throw Exception("User ID not found.");

      // ហៅ API ៣ ព្រមគ្នា (Profile, Transactions, និង Wallet Balance)
      final results = await Future.wait([
        _authService.getProfile(userId),
        _expenseService.getAllTransactions(
          limit: 10,
          sortBy: 'date',
          sortOrder: 'desc',
        ),
        _getWalletBalanceFromApi(), // ✅ ហៅ Function ថ្មីខាងក្រោម
      ]);

      final user = User.fromJson(results[0] as Map<String, dynamic>);
      final transactions = results[1] as List<TransactionModel>;
      final walletBalance = results[2] as WalletBalanceModel; // ✅

      return WalletData(
        user: user,
        transactions: transactions,
        walletBalance: walletBalance,
      );
    } catch (e) {
      throw Exception('Failed to load wallet data: $e');
    }
  }

  // ✅ 1. Function ទាញយក Wallet Balance (GET /wallet)
  Future<WalletBalanceModel> _getWalletBalanceFromApi() async {
    try {
      final response = await _apiService.client.get('/wallet');
      return WalletBalanceModel.fromJson(response.data);
    } catch (e) {
      // បើមិនទាន់មាន Wallet, return 0
      return WalletBalanceModel(id: '', balance: 0.0, userId: '');
    }
  }

  // ✅ 2. Function សម្រាប់ Top Up (PATCH /wallet/adjust)
  Future<void> topUpWallet(double amount) async {
    try {
      await _apiService.client.patch(
        '/wallet/adjust',
        data: {"amount": amount}, // amount វិជ្ជមាន = បូកចូល
      );
    } catch (e) {
      throw Exception('Top Up failed: $e');
    }
  }
}
