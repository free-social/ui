import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radii.dart';
import '../core/theme/app_spacing.dart';
import '../models/transaction_model.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';
import 'transaction_form_screen.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static const List<String> _filters = [
    'All',
    'Food',
    'Travel',
    'Shopping',
    'Bills',
    'Other',
  ];

  final ScrollController _scrollController = ScrollController();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTransactions(category: _selectedFilter);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 240) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await context.read<ExpenseProvider>().fetchTransactions(
          page: 1,
          category: _selectedFilter,
          sortBy: 'amount',
          sortOrder: 'desc',
        );
  }

  void _fetchTransactions({required String category}) {
    context.read<ExpenseProvider>().fetchTransactions(
          page: 1,
          category: category,
          sortBy: 'amount',
          sortOrder: 'desc',
        );
  }

  void _loadMore() {
    final provider = context.read<ExpenseProvider>();
    if (!provider.isLoading) {
      provider.fetchTransactions(page: provider.currentPage + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Consumer<ExpenseProvider>(
          builder: (context, provider, child) {
            final transactions = provider.transactions;
            final total = transactions.fold<double>(
              0,
              (sum, item) => sum + item.amount,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: MediaQuery.of(context).size.height * 0.22,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [scheme.primary, AppColors.accent],
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppSpacing.xl,
                      right: AppSpacing.xl,
                      bottom: -56.0,
                      child: _HomeHeader(
                        userName: (user?.username.trim().isNotEmpty ?? false)
                            ? user!.username
                            : 'User',
                        avatarUrl: user?.avatar,
                        total: total,
                        selectedFilter: _selectedFilter,
                        isDark: isDark,
                        scheme: scheme,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 56.0 + AppSpacing.xl),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: scheme.primary,
                    displacement: 20,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xl,
                              0,
                              AppSpacing.xl,
                              AppSpacing.lg,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Categories',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                SizedBox(
                                  height: 42,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _filters.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: AppSpacing.sm),
                                    itemBuilder: (context, index) {
                                      final filter = _filters[index];
                                      final isSelected = filter == _selectedFilter;
                                      return FilterChip(
                                        selected: isSelected,
                                        onSelected: (_) {
                                          setState(() => _selectedFilter = filter);
                                          _fetchTransactions(category: filter);
                                        },
                                        label: Text(filter),
                                        showCheckmark: false,
                                        side: BorderSide(
                                          color: isSelected
                                              ? scheme.primary
                                              : theme.dividerColor,
                                        ),
                                        backgroundColor: scheme.surface,
                                        selectedColor:
                                            scheme.primary.withValues(alpha: 0.14),
                                        labelStyle:
                                            theme.textTheme.bodyMedium?.copyWith(
                                          color: isSelected
                                              ? scheme.primary
                                              : scheme.onSurface,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.pill,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                Row(
                                  children: [
                                    Text(
                                      'Recent activity',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.sm,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.pill,
                                        ),
                                      ),
                                      child: Text(
                                        '${transactions.length} items',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                            ),
                          ),
                        ),
                        if (provider.isLoading && provider.currentPage == 1)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl,
                            ),
                            sliver: SliverList.builder(
                              itemCount: 5,
                              itemBuilder: (_, __) => const _TransactionSkeleton(),
                            ),
                          )
                        else if (transactions.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyTransactionsState(
                              selectedFilter: _selectedFilter,
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xl,
                              0,
                              AppSpacing.xl,
                              120,
                            ),
                            sliver: SliverList.builder(
                              itemCount: transactions.length + (provider.isLoading ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= transactions.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(AppSpacing.xl),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }

                                final transaction = transactions[index];
                                return _TransactionCard(
                                  transaction: transaction,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TransactionFormScreen(
                                          transaction: transaction,
                                        ),
                                      ),
                                    );
                                  },
                                  onDelete: () => context
                                      .read<ExpenseProvider>()
                                      .deleteTransaction(transaction.id),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String userName;
  final String? avatarUrl;
  final double total;
  final String selectedFilter;
  final bool isDark;
  final ColorScheme scheme;

  const _HomeHeader({
    required this.userName,
    required this.avatarUrl,
    required this.total,
    required this.selectedFilter,
    required this.isDark,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = isDark ? const Color(0xFF10201D) : Colors.white;
    final textColor = isDark ? Colors.white : scheme.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(avatarUrl!)
                    : null,
                child: (avatarUrl == null || avatarUrl!.isEmpty)
                    ? Icon(Icons.person_rounded, color: scheme.primary)
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  DateFormat('MMM d').format(DateTime.now()),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '\$${total.toStringAsFixed(2)}',
            style: theme.textTheme.displaySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            selectedFilter == 'All'
                ? 'Total transactions'
                : 'Total for $selectedFilter',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: textColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TransactionCard({
    required this.transaction,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categoryColor = _categoryColor(transaction.category);

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _showDeleteConfirmation(context),
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _categoryIcon(transaction.category),
                    color: categoryColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description.isNotEmpty
                            ? transaction.description
                            : _capitalize(transaction.category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        DateFormat('MMM d, y • h:mm a').format(transaction.date),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${transaction.amount.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _capitalize(transaction.category),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: categoryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: Text(
          'Delete transaction?',
          style: theme.textTheme.titleLarge,
        ),
        content: Text(
          'This will permanently remove the transaction from your history.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _TransactionSkeleton extends StatelessWidget {
  const _TransactionSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            const Expanded(
              child: Column(
                children: [
                  _SkeletonBar(widthFactor: 0.72),
                  SizedBox(height: AppSpacing.sm),
                  _SkeletonBar(widthFactor: 0.45, height: 12),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            const _SkeletonBar(widthFactor: 0.18),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  final double widthFactor;
  final double height;

  const _SkeletonBar({
    required this.widthFactor,
    this.height = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: theme.dividerColor.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _EmptyTransactionsState extends StatelessWidget {
  final String selectedFilter;

  const _EmptyTransactionsState({
    required this.selectedFilter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: scheme.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No transactions yet',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                selectedFilter == 'All'
                    ? 'Start by adding your first expense.'
                    : 'No transactions found for $selectedFilter.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _categoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'food':
      return Icons.restaurant_outlined;
    case 'travel':
      return Icons.directions_car_outlined;
    case 'shopping':
      return Icons.shopping_bag_outlined;
    case 'bills':
      return Icons.receipt_long_outlined;
    case 'rent':
      return Icons.home_outlined;
    default:
      return Icons.category_outlined;
  }
}

Color _categoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'food':
      return const Color(0xFF1C9C76);
    case 'travel':
      return const Color(0xFFE29E2B);
    case 'shopping':
      return const Color(0xFF8D63D2);
    case 'bills':
      return AppColors.danger;
    case 'rent':
      return const Color(0xFF4B6ED6);
    default:
      return const Color(0xFF607D8B);
  }
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}
