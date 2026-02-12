import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/auth_provider.dart';
import '../models/transaction_model.dart';
import 'transaction_form_screen.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final Color kPrimaryColor = const Color(0xFF00BFA5);
  final ScrollController _scrollController = ScrollController();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTransactions(reset: true);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ✅ 1. NEW: Future method for Pull-to-Refresh
  Future<void> _onRefresh() async {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    // We await this so the spinner stays until data is loaded
    await provider.fetchTransactions(
      page: 1,
      category: _selectedFilter,
      sortBy: 'amount',
      sortOrder: 'desc',
    );
  }

  void _fetchTransactions({required bool reset, String? category}) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final catToSend = category ?? _selectedFilter;

    provider.fetchTransactions(
      page: 1,
      category: catToSend,
      sortBy: 'amount',
      sortOrder: 'desc',
    );
  }

  void _loadMore() {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    if (!provider.isLoading) {
      provider.fetchTransactions(page: provider.currentPage + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1D1D1D);
    final secondaryTextColor = isDark
        ? Colors.grey[400]!
        : const Color(0xFFAAAAAA);

    return SafeArea(
      child: Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          final displayTotal = provider.transactions.fold(
            0.0,
            (sum, item) => sum + item.amount,
          );

          return Column(
            children: [
              // --- HEADER SECTION ---
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: cardColor, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.grey[200],
                                backgroundImage:
                                    (user?.avatar != null &&
                                        user!.avatar.isNotEmpty)
                                    ? NetworkImage(user.avatar)
                                    : const NetworkImage(
                                            "https://i.pravatar.cc/150?img=12",
                                          )
                                          as ImageProvider,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Welcome back",
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  user?.username ?? "User",
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        _buildNotificationIcon(cardColor, isDark),
                      ],
                    ),
              
                    const SizedBox(height: 20),
                    Text(
                      "\$${displayTotal.toStringAsFixed(2)}",
                      style: TextStyle(
                        color: kPrimaryColor,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      _selectedFilter == 'All'
                          ? "Total recently"
                          : "Total for $_selectedFilter",
                      style: TextStyle(color: secondaryTextColor, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // --- FILTER BAR ---
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _buildFilterChip('All', isDark),
                    _buildFilterChip('Food', isDark),
                    _buildFilterChip('Travel', isDark),
                    _buildFilterChip('Shopping', isDark),
                    _buildFilterChip('Bills', isDark),
                    _buildFilterChip('Other', isDark),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // --- TRANSACTION LIST (Infinite Scroll + Refresh) ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Recent Transactions",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                          Text(
                            "${provider.transactions.length}",
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      // ✅ 2. Wrapped in RefreshIndicator
                      child: RefreshIndicator(
                        onRefresh: _onRefresh,
                        color: kPrimaryColor,
                        backgroundColor: cardColor,
                        child: provider.isLoading && provider.currentPage == 1
                            ? _buildSkeletonList(
                                cardColor,
                                Theme.of(context).brightness == Brightness.dark,
                              )
                            : ListView.builder(
                                // ✅ 3. AlwaysScrollableScrollPhysics ensures you can pull
                                // to refresh even if the list is short/empty
                                physics: const AlwaysScrollableScrollPhysics(),
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                itemCount: provider.transactions.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == provider.transactions.length) {
                                    return provider.isLoading
                                        ? Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                color: kPrimaryColor,
                                              ),
                                            ),
                                          )
                                        : const SizedBox(height: 80);
                                  }

                                  return _buildTransactionCard(
                                    context,
                                    provider.transactions[index],
                                    cardColor,
                                    primaryTextColor,
                                    secondaryTextColor,
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildFilterChip(String label, bool isDark) {
    final bool isSelected =
        _selectedFilter.toLowerCase() == label.toLowerCase();

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedFilter = label);
          _fetchTransactions(reset: true, category: label);
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? kPrimaryColor
                : (isDark ? Colors.grey[800] : Colors.grey[200]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : Colors.black54),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(Color bgColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.0 : 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Icon(
        Icons.notifications_none,
        size: 24,
        color: isDark ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    TransactionModel transaction,
    Color cardColor,
    Color titleColor,
    Color subColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _getCategoryColor(transaction.category).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getCategoryIcon(transaction.category),
            color: _getCategoryColor(transaction.category),
            size: 24,
          ),
        ),
        title: Text(
          transaction.description.isNotEmpty
              ? transaction.description
              : _capitalize(transaction.category),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: titleColor,
          ),
        ),
        subtitle: Text(
          DateFormat('MMM d, y').format(transaction.date),
          style: TextStyle(color: subColor, fontSize: 13),
        ),
        trailing: Text(
          "\$${transaction.amount.toStringAsFixed(2)}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: titleColor,
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionFormScreen(transaction: transaction),
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.local_cafe;
      case 'travel':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'bills':
        return Icons.receipt_long;
      case 'rent':
        return Icons.home;
      case 'other':
        return Icons.category;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Colors.teal;
      case 'travel':
        return Colors.orange;
      case 'shopping':
        return Colors.purple;
      case 'bills':
        return const Color(0xFFFF5252);
      case 'rent':
        return Colors.indigo;
      case 'other':
        return Colors.blueGrey;
      default:
        return Colors.blueGrey;
    }
  }

  // Skeleton Loading Widgets
  Widget _buildSkeletonList(Color cardColor, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: 5, // Show 5 skeleton items
      itemBuilder: (context, index) {
        return _buildSkeletonTransactionCard(cardColor, isDark);
      },
    );
  }

  Widget _buildSkeletonTransactionCard(Color cardColor, bool isDark) {
    final shimmerBaseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final shimmerHighlightColor = isDark
        ? Colors.grey[700]!
        : Colors.grey[100]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.4, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Opacity(opacity: value, child: child);
          },
          onEnd: () {
            // Loop animation
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) setState(() {});
            });
          },
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: shimmerBaseColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        title: Container(
          width: double.infinity,
          height: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                shimmerBaseColor,
                shimmerHighlightColor,
                shimmerBaseColor,
              ],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        subtitle: Container(
          width: 100,
          height: 13,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: shimmerBaseColor.withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        trailing: Container(
          width: 70,
          height: 18,
          decoration: BoxDecoration(
            color: shimmerBaseColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
