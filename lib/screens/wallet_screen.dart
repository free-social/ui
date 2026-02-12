import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/expense_provider.dart';
import '../../utils/snackbar_helper.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late PageController _pageController; // For card swipe animation

  @override
  void initState() {
    super.initState();

    // Initialize page controller for card carousel
    _pageController = PageController(viewportFraction: 1);

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Fetch wallet data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().fetchWalletData();
      _animationController.forward(); // Start animation
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // 🟢 1. Add Wallet - Modern Dialog
  void _showAddWalletDialog(BuildContext context) {
    final TextEditingController amountController = TextEditingController();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.teal.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_circle,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        "Add to Wallet",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Enter Amount",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white70
                              : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: "0.00",
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: Colors.green.shade600,
                          ),
                          filled: true,
                          fillColor: isDarkMode
                              ? Colors.grey.shade800
                              : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(20),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final amount =
                                    double.tryParse(amountController.text) ??
                                    0.0;
                                if (amount <= 0) return;
                                Navigator.pop(context);
                                _processTopUpWallet(amount, "Add Wallet");
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Add",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🔴 2. Renew Wallet - Modern Dialog
  void _showRenewWalletDialog(BuildContext context) {
    final TextEditingController amountController = TextEditingController();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade400, Colors.orange.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.sync_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        "Renew Wallet",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Set New Balance",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white70
                              : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "This will replace your current balance",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: "0.00",
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: Colors.orange.shade600,
                          ),
                          filled: true,
                          fillColor: isDarkMode
                              ? Colors.grey.shade800
                              : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(20),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final amount = double.tryParse(
                                  amountController.text,
                                );
                                if (amount == null || amount < 0) return;
                                Navigator.pop(context);
                                _processUpdateWallet(amount, "Renew Wallet");
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Update",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ⚪ 3. Reset Wallet - Modern Dialog
  void _showResetWalletDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade400, Colors.pink.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        "Reset Wallet",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red.shade600,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "This will reset your wallet balance to \$0.00",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                _processUpdateWallet(0.0, "Reset Wallet");
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Reset",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Helper Functions ---
  // Future<void> _processAddWallet(double amount) async {
  //   showInfoSnackBar(context, 'Creating wallet...');
  //   try {
  //     final walletProvider = context.read<WalletProvider>();

  //     // Only create/add wallet balance, no transaction needed
  //     await walletProvider.addNewWallet(amount);

  //     if (mounted) showSuccessSnackBar(context, 'Wallet created successfully!');
  //   } catch (e) {
  //     if (mounted) showErrorSnackBar(context, 'Failed to create wallet: $e');
  //   }
  // }

  Future<void> _processTransaction(
    double amount,
    String category,
    String description, {
    required bool isAdd,
  }) async {
    showInfoSnackBar(context, 'Processing...');
    try {
      final walletProvider = context.read<WalletProvider>();
      final expenseProvider = context.read<ExpenseProvider>();

      // Step 1: Update wallet balance
      await walletProvider.topUpWallet(isAdd ? amount : -amount);

      // Step 2: Create transaction record
      try {
        await expenseProvider.addTransaction(
          isAdd ? amount : -amount,
          category,
          description,
          DateTime.now(),
        );
      } catch (transactionError) {
        // If transaction creation fails, show warning but don't fail entirely
        // The wallet balance was already updated successfully
        if (mounted) {
          showErrorSnackBar(
            context,
            'Wallet updated but transaction record failed: $transactionError',
          );
        }
        return; // Exit early, don't show success
      }

      // Both operations succeeded
      if (mounted) showSuccessSnackBar(context, 'Success!');
    } catch (e) {
      // Wallet update failed
      if (mounted) showErrorSnackBar(context, 'Failed to update wallet: $e');
    }
  }

  Future<void> _processTopUpWallet(double amount, String actionName) async {
    showInfoSnackBar(context, 'Processing...');
    try {
      await context.read<WalletProvider>().topUpWallet(amount);
      if (mounted) showSuccessSnackBar(context, '$actionName Successful!');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Error: $e');
    }
  }

  Future<void> _processUpdateWallet(
    double newBalance,
    String actionName,
  ) async {
    showInfoSnackBar(context, 'Updating...');
    try {
      await context.read<WalletProvider>().updateWalletBalance(newBalance);
      if (mounted) showSuccessSnackBar(context, '$actionName Successful!');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Error: $e');
    }
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
        body: Consumer<WalletProvider>(
          builder: (context, walletProvider, child) {
            // Handle loading state
            if (walletProvider.isLoading && walletProvider.walletData == null) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
              );
            }

            // Handle error state
            if (walletProvider.error != null &&
                walletProvider.walletData == null) {
              return Center(
                child: Text(
                  'Error: ${walletProvider.error}',
                  style: TextStyle(color: primaryTextColor),
                ),
              );
            }

            // Handle no data
            if (walletProvider.walletData == null) {
              return Center(
                child: Text(
                  'No Data',
                  style: TextStyle(color: primaryTextColor),
                ),
              );
            }

            // Extract data from provider
            final walletData = walletProvider.walletData!;
            final lastMonthExpense = walletProvider.lastMonthExpense;
            final transactions = walletData.transactions;
            double calcBalance = 0;
            for (var tx in transactions) calcBalance += tx.amount;
            final walletModel = walletData.walletBalance;

            return RefreshIndicator(
              onRefresh: () => walletProvider.refreshData(),
              color: const Color(0xFF00BFA5),
              child: SingleChildScrollView(
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

                      // Animated wallet cards
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildTopCardsSection(
                            calcBalance,
                            walletModel.balance,
                            lastMonthExpense,
                          ),
                        ),
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
                    ],
                  ),
                ),
              ),
            );
          },
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

    final cards = [
      {
        "title": "Transaction Net",
        "amount": historyBalance,
        "icon": Icons.history,
        "colors": [
          Colors.blue.shade400,
          Colors.blue.shade600,
          Colors.blue.shade800.withOpacity(0.9),
        ],
      },
      {
        "title": "Total Wallet",
        "amount": realWalletBalance,
        "icon": Icons.account_balance_wallet,
        "colors": [
          Colors.teal.shade400,
          Colors.teal.shade600,
          Colors.teal.shade800.withOpacity(0.9),
        ],
      },
      {
        "title": "Expense ($prevMonthName)",
        "amount": lastMonthExpense,
        "icon": Icons.calendar_today,
        "colors": [
          Colors.red.shade400,
          Colors.red.shade600,
          Colors.red.shade800.withOpacity(0.9),
        ],
      },
    ];

    return SizedBox(
      height: 200, // Increased height to accommodate scale
      width: double.infinity,
      child: PageView.builder(
        controller: _pageController,
        itemCount: cards.length,
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 1.0;
              if (_pageController.position.haveDimensions) {
                value = _pageController.page! - index;
                value = (1 - (value.abs() * 0.3)).clamp(0.8, 1.0);
              }

              return Center(
                child: Transform.scale(scale: value, child: child),
              );
            },
            child: _buildSingleCard(
              cards[index]["title"] as String,
              cards[index]["amount"] as double,
              cards[index]["icon"] as IconData,
              cards[index]["colors"] as List<Color>,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSingleCard(
    String title,
    double amount,
    IconData icon,
    List<Color> gradientColors, // Keeping this if you want to override per card
  ) {
    // --- OPTION 1: "Aurora" (Teal -> Purple -> Pink) ---
    // Rich, modern, and very colorful
    const List<Color> activeGradient = [
      Color(0xFF0093E9),
      Color(0xFF80D0C7),
      Color(0xFF8A2BE2),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: activeGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          Text(
            "\$${amount.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              shadows: [
                Shadow(
                  offset: Offset(0, 2),
                  blurRadius: 4,
                  color: Colors.black26,
                ),
              ],
            ),
          ),
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
}
