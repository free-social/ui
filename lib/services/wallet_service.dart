import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_balance_model.dart';
import 'auth_service.dart';
import 'expense_service.dart';
import 'api_service.dart';

class WalletData {
  final User user;
  final List<TransactionModel> transactions;
  final WalletBalanceModel walletBalance;
  final double lastMonthExpense;

  WalletData({
    required this.user,
    required this.transactions,
    required this.walletBalance,
    required this.lastMonthExpense,
  });
}

class WalletService {
  final AuthService _authService = AuthService();
  final ExpenseService _expenseService = ExpenseService();
  final ApiService _apiService = ApiService();

  Future<WalletData> fetchWalletData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) throw Exception("User ID not found.");

      // គណនាខែមុន
      DateTime now = DateTime.now();
      int prevMonth = now.month - 1;
      int prevYear = now.year;

      if (prevMonth == 0) {
        prevMonth = 12;
        prevYear = now.year - 1;
      }

      // ហៅ API ៤ ព្រមគ្នា
      final results = await Future.wait([
        _authService.getProfile(userId), // index 0
        _expenseService.getAllTransactions(
          limit: 10,
          sortBy: 'date',
          sortOrder: 'desc',
        ), // index 1
        _getWalletBalanceFromApi(), // index 2 (Function នេះត្រូវបានបង្កើតខាងក្រោម)
        _expenseService.getMonthlyExpenseTotal(prevMonth, prevYear), // index 3
      ]);

      return WalletData(
        user: User.fromJson(results[0] as Map<String, dynamic>),
        transactions: results[1] as List<TransactionModel>,
        walletBalance: results[2] as WalletBalanceModel,
        lastMonthExpense: results[3] as double,
      );
    } catch (e) {
      throw Exception('Failed to load wallet data: $e');
    }
  }

  // ✅ 1. Function ទាញយក Wallet Balance (កែ Error: _getWalletBalanceFromApi isn't defined)
  Future<WalletBalanceModel> _getWalletBalanceFromApi() async {
    try {
      final response = await _apiService.client.get('/wallet');
      return WalletBalanceModel.fromJson(response.data);
    } catch (e) {
      // បើមិនទាន់មាន Wallet, return 0
      return WalletBalanceModel(id: '', balance: 0.0, userId: '');
    }
  }

  // ✅ 2. Function សម្រាប់ Top Up (កែ Error: topUpWallet isn't defined)
  Future<void> topUpWallet(double amount) async {
    try {
      // amount វិជ្ជមាន = បូកចូល, អវិជ្ជមាន = ដកចេញ
      await _apiService.client.patch(
        '/wallet/adjust',
        data: {"amount": amount},
      );
    } catch (e) {
      throw Exception('Top Up failed: $e');
    }
  }
}
