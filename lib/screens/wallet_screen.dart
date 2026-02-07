import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_balance_model.dart'; // ✅ Import ថ្មី
import '../../services/wallet_service.dart';
import '../../services/expense_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Future<WalletData> _walletFuture;
  final WalletService _walletService = WalletService();
  final ExpenseService _expenseService = ExpenseService();

  // រក្សាទុក Balance បច្ចុប្បន្នដើម្បីផ្ទៀងផ្ទាត់
  double _currentWalletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() {
      _walletFuture = _walletService.fetchWalletData();
    });
  }

  // ✅ Function Top Up (ប្រើ API /wallet/adjust)
  void _showTopUpDialog(BuildContext context) {
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Top Up Wallet"),
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Processing...")));

                try {
                  // ✅ ហៅទៅ API Wallet Adjust
                  await _walletService.topUpWallet(amount);

                  // (Optional) បង្កើត Transaction record ផងដែរដើម្បីអោយឃើញក្នុង list
                  await _expenseService.createTransaction(
                    TransactionModel(
                      id: "",
                      amount: amount,
                      category: "Top Up",
                      description: "Wallet Deposit",
                      date: DateTime.now(),
                    ),
                  );

                  await _refreshData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Top Up Successful!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  // ✅ Function សម្រាប់ Add Expense (ឧទាហរណ៍ការចាយលុយ)
  // កន្លែងនេះសំខាន់៖ ឆែកមើលលុយសិន មុននឹងឱ្យចាយ
  void _simulateAddExpense(BuildContext context) {
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Expense"),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: "Enter expense amount",
              prefixText: "\$ ",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0.0;

                // 🛑 CHECK: បើលុយក្នុង Wallet - ចំណាយ < 0, ហាមឃាត់!
                if ((_currentWalletBalance - amount) < 0) {
                  Navigator.pop(context);
                  _showWarningDialog(context); // បង្ហាញសារព្រមាន
                  return;
                }

                Navigator.pop(context);

                // បើលុយគ្រាន់គ្រាន់ បន្តហៅ API...
                try {
                  // 1. កាត់លុយពី Wallet (Adjust with negative value)
                  await _walletService.topUpWallet(-amount);
                  // 2. បង្កើត Transaction
                  await _expenseService.createTransaction(
                    TransactionModel(
                      id: "",
                      amount: -amount,
                      category: "Expense",
                      description: "Payment",
                      date: DateTime.now(),
                    ),
                  );
                  await _refreshData();
                } catch (e) {
                  print(e);
                }
              },
              child: const Text("Pay", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // 🛑 ផ្ទាំងសារព្រមាន
  void _showWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ Insufficient Balance"),
        content: const Text(
          "Your wallet balance is too low! Please Top Up first.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: RefreshIndicator(
          onRefresh: _refreshData,
          child: FutureBuilder<WalletData>(
            future: _walletFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasData) {
                final data = snapshot.data!;

                // គណនាសម្រាប់ Card 1 (Transaction History)
                double calcBalance = 0;
                double totalExpense = 0;
                for (var tx in data.transactions) {
                  calcBalance += tx.amount;
                  if (tx.amount < 0) totalExpense += tx.amount;
                }

                // យកទិន្នន័យសម្រាប់ Card 2 (Real Wallet API)
                final walletModel = data.walletBalance;
                _currentWalletBalance =
                    walletModel.balance; // Update variable សម្រាប់ Check

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Text(
                          "My Wallet",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ✅ បង្ហាញ 3 Cards
                        _buildTopCardsSection(
                          calcBalance,
                          walletModel.balance,
                          totalExpense,
                        ),

                        const SizedBox(height: 30),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => _showTopUpDialog(context),
                              child: _buildActionButton(
                                Icons.add,
                                "Top Up",
                                const Color(0xFFE0F7F5),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _simulateAddExpense(
                                context,
                              ), // ឧទាហរណ៍ប៊ូតុងចាយលុយ
                              child: _buildActionButton(
                                Icons.remove,
                                "Pay",
                                const Color(0xFFFFEBEE),
                              ),
                            ),
                            _buildActionButton(
                              Icons.qr_code,
                              "Scan",
                              const Color(0xFFE8EAF6),
                            ),
                            _buildActionButton(
                              Icons.more_horiz,
                              "More",
                              const Color(0xFFF5F5F5),
                            ),
                          ],
                        ),

                        // List Transactions... (ដូចកូដចាស់)
                        const SizedBox(height: 20),
                        // ... ដាក់ ListView ដូចមុននៅទីនេះ ...
                      ],
                    ),
                  ),
                );
              }
              return const Center(child: Text("No Data"));
            },
          ),
        ),
      ),
    );
  }

  // Widget សម្រាប់កាតទាំង ៣
  Widget _buildTopCardsSection(
    double historyBalance,
    double realWalletBalance,
    double expense,
  ) {
    return SizedBox(
      height: 200,
      child: PageView(
        controller: PageController(viewportFraction: 0.92),
        padEnds: false,
        children: [
          // Card 1: Calculated Balance (ពី Transactions)
          _buildSingleCard(
            "Transaction Net",
            historyBalance,
            const Color(0xFF42A5F5),
            const Color(0xFF1976D2),
            Icons.history,
          ),

          // Card 2: Real Wallet (ពី API /wallet) - នេះហើយដែលអ្នកចង់បាន
          _buildSingleCard(
            "Total Wallet",
            realWalletBalance,
            const Color(0xFF00C4B4),
            const Color(0xFF009E91),
            Icons.account_balance_wallet,
          ),

          // Card 3: Expense
          _buildSingleCard(
            "Total Expense",
            expense,
            const Color(0xFFEF5350),
            const Color(0xFFD32F2F),
            Icons.arrow_circle_up,
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
          const Text("....", style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color bgColor) {
    return Column(
      children: [
        Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
