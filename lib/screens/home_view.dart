import 'package:flutter/material.dart';
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
    final user = context.watch<AuthProvider>().user;

    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        final transactions = provider.transactions;
        final total = transactions.fold<double>(
          0,
          (sum, item) => sum + item.amount,
        );

        return SafeArea(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: scheme.primary,
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
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HomeHeader(
                          userName: (user?.username.trim().isNotEmpty ?? false)
                              ? user!.username
                              : 'User',
                          avatarUrl: user?.avatar,
                          total: total,
                          selectedFilter: _selectedFilter,
                        ),
                        const SizedBox(height: AppSpacing.xl),
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
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String userName;
  final String? avatarUrl;
  final double total;
  final String selectedFilter;

  const _HomeHeader({
    required this.userName,
    required this.avatarUrl,
    required this.total,
    required this.selectedFilter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            AppColors.accent,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.24),
            blurRadius: 30,
            offset: const Offset(0, 14),
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
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(avatarUrl!)
                    : null,
                child: (avatarUrl == null || avatarUrl!.isEmpty)
                    ? const Icon(Icons.person_rounded, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.84),
                      ),
                    ),
                    Text(
                      userName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
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
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  DateFormat('MMM d').format(DateTime.now()),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '\$${total.toStringAsFixed(2)}',
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            selectedFilter == 'All'
                ? 'Total transactions'
                : 'Total for $selectedFilter',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
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
