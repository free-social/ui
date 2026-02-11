import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_balance_model.dart';
import '../../services/wallet_service.dart';
import '../../services/expense_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Future<List<dynamic>> _dataFuture;

  final WalletService _walletService = WalletService();
  final ExpenseService _expenseService = ExpenseService();

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    DateTime now = DateTime.now();
    int prevMonth = now.month - 1;
    int prevYear = now.year;

    if (prevMonth == 0) {
      prevMonth = 12;
      prevYear = now.year - 1;
    }

    setState(() {
      _dataFuture = Future.wait([
        _walletService.fetchWalletData(),
        _expenseService.getMonthlyExpenseTotal(prevMonth, prevYear),
      ]);
    });
  }

  // 🟢 1. Add Wallet
  void _showAddWalletDialog(BuildContext context) {
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Wallet"),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: "Enter amount",
              prefixText: "\$ ",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0.0;
                if (amount <= 0) return;
                Navigator.pop(context);
                _processTransaction(
                  amount,
                  "Add Wallet",
                  "Wallet Deposit",
                  isAdd: true,
                );
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  // 🔴 2. Renew Wallet
  void _showRenewWalletDialog(BuildContext context) {
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Renew Wallet"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Set a new total balance.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: "New Balance",
                  prefixText: "\$ ",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount < 0) return;
                Navigator.pop(context);
                _processUpdateWallet(amount, "Renew Wallet");
              },
              child: const Text(
                "Update",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // ⚪ 3. Reset Wallet
  void _showResetWalletDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Reset Wallet"),
          content: const Text("Reset balance to \$0.00?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                _processUpdateWallet(0.0, "Reset Wallet");
              },
              child: const Text("Reset", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- Helper Functions ---
  Future<void> _processTransaction(
    double amount,
    String category,
    String description, {
    required bool isAdd,
  }) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Processing...")));
    try {
      await _walletService.topUpWallet(isAdd ? amount : -amount);
      await _expenseService.createTransaction(
        TransactionModel(
          id: "",
          amount: isAdd ? amount : -amount,
          category: category,
          description: description,
          date: DateTime.now(),
        ),
      );
      await _refreshData();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Success!"),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _processUpdateWallet(
    double newBalance,
    String actionName,
  ) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Updating...")));
    try {
      await _walletService.updateWalletBalance(newBalance);
      await _refreshData();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$actionName Successful!"),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // ✅ 1. Function គណនាលុយសរុបតាម Category (ថ្មី)
  Map<String, double> _calculateCategoryTotals(
    List<TransactionModel> transactions,
  ) {
    Map<String, double> totals = {};
    for (var tx in transactions) {
      if (tx.amount < 0) {
        String cat = tx.category.isNotEmpty
            ? tx.category[0].toUpperCase() +
                  tx.category.substring(1).toLowerCase()
            : "Other";
        totals[cat] = (totals[cat] ?? 0) + tx.amount.abs();
      }
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    // 🌑 Dark Mode Check
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDarkMode
        ? const Color(0xFF121212)
        : const Color(0xFFF5F7FA);
    final cardBackgroundColor = isDarkMode
        ? const Color(0xFF1E1E1E)
        : Colors.white;
    final primaryTextColor = isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.white70 : Colors.grey;

    return SafeArea(
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: RefreshIndicator(
          onRefresh: _refreshData,
          child: FutureBuilder<List<dynamic>>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasData) {
                final walletData = snapshot.data![0] as WalletData;
                final lastMonthExpense = snapshot.data![1] as double;
                final transactions = walletData.transactions;
                double calcBalance = 0;
                for (var tx in transactions) calcBalance += tx.amount;
                final walletModel = walletData.walletBalance;

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          "My Wallet",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 20),

                        _buildTopCardsSection(
                          calcBalance,
                          walletModel.balance,
                          lastMonthExpense,
                        ),

                        const SizedBox(height: 30),

                        // Button Container
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: cardBackgroundColor,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              GestureDetector(
                                onTap: () => _showAddWalletDialog(context),
                                child: _buildNewActionButton(
                                  Icons.add,
                                  "Add Wallet",
                                  const Color(0xFFE0F7F5),
                                  const Color(0xFF00C4B4),
                                  isDarkMode,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 50,
                                color: secondaryTextColor.withOpacity(0.2),
                              ),
                              GestureDetector(
                                onTap: () => _showRenewWalletDialog(context),
                                child: _buildNewActionButton(
                                  Icons.sync,
                                  "Renew Wallet",
                                  const Color(0xFFFFEBEE),
                                  const Color(0xFFEF5350),
                                  isDarkMode,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 50,
                                color: secondaryTextColor.withOpacity(0.2),
                              ),
                              GestureDetector(
                                onTap: () => _showResetWalletDialog(context),
                                child: _buildNewActionButton(
                                  Icons.refresh,
                                  "Reset Wallet",
                                  const Color(0xFFE8EAF6),
                                  const Color(0xFF3F51B5),
                                  isDarkMode,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // ✅ Title ថ្មី: Expenses by Category
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Expenses by Category",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // ✅ List ថ្មី: បង្ហាញ Category Summary
                        Builder(
                          builder: (context) {
                            final categoryTotals = _calculateCategoryTotals(
                              transactions,
                            );
                            final categories = categoryTotals.keys.toList();

                            if (categoryTotals.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: Text(
                                  "No expenses yet.",
                                  style: TextStyle(color: secondaryTextColor),
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                String category = categories[index];
                                double amount = categoryTotals[category]!;

                                return _buildCategoryItem(
                                  category,
                                  amount,
                                  cardBackgroundColor,
                                  primaryTextColor,
                                  secondaryTextColor,
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                );
              }
              return Center(
                child: Text(
                  "No Data",
                  style: TextStyle(color: primaryTextColor),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildTopCardsSection(
    double historyBalance,
    double realWalletBalance,
    double lastMonthExpense,
  ) {
    DateTime now = DateTime.now();
    DateTime prevDate = DateTime(now.year, now.month - 1);
    String prevMonthName = DateFormat('MMM').format(prevDate);

    return SizedBox(
      height: 200,
      child: PageView(
        controller: PageController(viewportFraction: 0.92),
        padEnds: false,
        children: [
          _buildSingleCard(
            "Transaction Net",
            historyBalance,
            const Color(0xFF42A5F5),
            const Color(0xFF1976D2),
            Icons.history,
          ),
          _buildSingleCard(
            "Total Wallet",
            realWalletBalance,
            const Color(0xFF00C4B4),
            const Color(0xFF009E91),
            Icons.account_balance_wallet,
          ),
          _buildSingleCard(
            "Expense ($prevMonthName)",
            lastMonthExpense,
            const Color(0xFFEF5350),
            const Color(0xFFD32F2F),
            Icons.calendar_today,
          ),
        ],
      ),
    );
  }

  Widget _buildSingleCard(
    String title,
    double amount,
    Color c1,
    Color c2,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c1, c2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70)),
              Icon(icon, color: Colors.white),
            ],
          ),
          Text(
            "\$${amount.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text("Tap for detail", style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildNewActionButton(
    IconData icon,
    String label,
    Color bgColor,
    Color iconColor,
    bool isDarkMode,
  ) {
    return Column(
      children: [
        Container(
          height: 65,
          width: 65,
          decoration: BoxDecoration(
            color: isDarkMode ? bgColor.withOpacity(0.15) : bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  // ✅ 2. Widget សម្រាប់បង្ហាញ Category Item (ថ្មី)
  Widget _buildCategoryItem(
    String category,
    double amount,
    Color bgColor,
    Color titleColor,
    Color subTitleColor,
  ) {
    Map<String, IconData> icons = {
      "Food": Icons.fastfood,
      "Travel": Icons.directions_car,
      "Bills": Icons.receipt,
      "Shopping": Icons.shopping_bag,
      "Rent": Icons.home,
      "Other": Icons.category,
    };
    IconData iconData = icons[category] ?? Icons.category;
    Color iconColor;
    switch (category) {
      case "Food":
        iconColor = Colors.orange;
        break;
      case "Travel":
        iconColor = Colors.blue;
        break;
      case "Bills":
        iconColor = Colors.red;
        break;
      case "Shopping":
        iconColor = Colors.purple;
        break;
      case "Rent":
        iconColor = Colors.teal;
        break;
      default:
        iconColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              category,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: titleColor,
              ),
            ),
          ),
          Text(
            "- \$${amount.toStringAsFixed(2)}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }
}
