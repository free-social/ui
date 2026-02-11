import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../services/wallet_service.dart';
import '../../services/expense_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  // ✅ ប្រើ Future<List<dynamic>> ដើម្បីទាញយកទិន្នន័យ ២ ផ្សេងគ្នា (WalletData + ចំណាយខែមុន)
  late Future<List<dynamic>> _dataFuture;

  final WalletService _walletService = WalletService();
  final ExpenseService _expenseService = ExpenseService();

  double _currentWalletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    // 1. គណនាខែមុន (Previous Month)
    DateTime now = DateTime.now();
    int prevMonth = now.month - 1;
    int prevYear = now.year;

    // បើខែនេះខែ 1 (មករា) -> ខែមុនគឺខែ 12 (ធ្នូ) ឆ្នាំចាស់
    if (prevMonth == 0) {
      prevMonth = 12;
      prevYear = now.year - 1;
    }

    setState(() {
      // 2. ហៅ API ២ ព្រមគ្នា៖ ទិន្នន័យ Wallet និង ចំណាយខែមុន
      _dataFuture = Future.wait([
        _walletService.fetchWalletData(), // Index 0
        _expenseService.getMonthlyExpenseTotal(prevMonth, prevYear), // Index 1
      ]);
    });
  }

  // --- Function Top Up ---
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
                  await _walletService.topUpWallet(amount);
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

  // --- Function Add Expense ---
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

                if ((_currentWalletBalance - amount) < 0) {
                  Navigator.pop(context);
                  _showWarningDialog(context);
                  return;
                }

                Navigator.pop(context);

                try {
                  await _walletService.topUpWallet(-amount);
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
          color: const Color(0xFF00BFA5),
          child: FutureBuilder<List<dynamic>>(
            // ✅ ប្តូរទៅ List<dynamic>
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00BFA5)));
              } else if (snapshot.hasData) {
                // ✅ បំបែកទិន្នន័យពី List
                final walletData = snapshot.data![0] as WalletData;
                final lastMonthExpense =
                    snapshot.data![1] as double; // ទិន្នន័យចំណាយខែមុន

                final transactions = walletData.transactions;

                // គណនា Transaction Net (Card 1)
                double calcBalance = 0;
                for (var tx in transactions) {
                  calcBalance += tx.amount;
                }

                final walletModel = walletData.walletBalance;
                _currentWalletBalance = walletModel.balance;

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

                        // ✅ បង្ហាញ 3 Cards (ដោយដាក់ lastMonthExpense ចូល)
                        _buildTopCardsSection(
                          calcBalance,
                          walletModel.balance,
                          lastMonthExpense,
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
                              onTap: () => _simulateAddExpense(context),
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

                        const SizedBox(height: 30),

                        // Title: Recent Transactions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Recent Transactions",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: const Text("See All"),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Transaction List
                        transactions.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.only(top: 20),
                                child: Text(
                                  "No transactions yet.",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: transactions.length,
                                itemBuilder: (context, index) {
                                  final transaction = transactions[index];
                                  return _buildTransactionItem(transaction);
                                },
                              ),
                        const SizedBox(height: 50),
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

  // --- Widgets សម្រាប់ Design ---

  Widget _buildTopCardsSection(
    double historyBalance,
    double realWalletBalance,
    double lastMonthExpense,
  ) {
    // ✅ រកឈ្មោះខែមុន (Previous Month Name)
    DateTime now = DateTime.now();
    DateTime prevDate = DateTime(now.year, now.month - 1);
    String prevMonthName = DateFormat('MMM').format(prevDate); // ឧ. "Jan"

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

          // ✅ Card ទី 3: បង្ហាញចំណាយខែមុន
          _buildSingleCard(
            "Expense ($prevMonthName)",
            lastMonthExpense, // លេខនេះបានមកពី API
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

  Widget _buildTransactionItem(TransactionModel transaction) {
    final isIncome = transaction.amount > 0;
    final displayAmount = isIncome
        ? "+ \$${transaction.amount.toStringAsFixed(2)}"
        : "\$${transaction.amount.toStringAsFixed(2)}";
    final amountColor = isIncome ? Colors.green : Colors.black87;

    IconData iconData = Icons.shopping_bag;
    Color iconBgColor = Colors.orange;

    if (isIncome) {
      iconData = Icons.arrow_downward;
      iconBgColor = Colors.green;
    } else if (transaction.category.toLowerCase().contains('top up')) {
      iconData = Icons.add_card;
      iconBgColor = Colors.blue;
    }

    String formattedDate = DateFormat('MMM d, h:mm a').format(transaction.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconBgColor),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description.isNotEmpty
                      ? transaction.description
                      : transaction.category,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            displayAmount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}
