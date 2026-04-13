import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radii.dart';
import '../core/theme/app_spacing.dart';
import '../providers/wallet_provider.dart';
import '../utils/snackbar_helper.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().fetchWalletData();
    });
  }

  Future<void> _showWalletAmountDialog({
    required String title,
    required String description,
    required String confirmLabel,
    required Future<void> Function(double amount) onSubmit,
  }) async {
    final controller = TextEditingController();
    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: Text(title, style: theme.textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text.trim());
              if (amount == null || amount < 0) {
                return;
              }

              Navigator.of(dialogContext).pop();
              await onSubmit(amount);
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: const Text('Reset wallet?'),
        content: const Text(
          'This will set the wallet balance to \$0.00.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _processWalletAction(
        actionLabel: 'Reset wallet',
        action: () => context.read<WalletProvider>().updateWalletBalance(0.0),
      );
    }
  }

  Future<void> _processWalletAction({
    required String actionLabel,
    required Future<void> Function() action,
  }) async {
    showInfoSnackBar(context, '$actionLabel in progress...');
    try {
      await action();
      if (mounted) {
        showSuccessSnackBar(context, '$actionLabel successful');
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          if (walletProvider.isLoading && walletProvider.walletData == null) {
            return const _WalletLoadingState();
          }

          if (walletProvider.error != null && walletProvider.walletData == null) {
            return _WalletMessageState(
              title: 'Could not load wallet',
              message: walletProvider.error!,
              actionLabel: 'Try again',
              onPressed: walletProvider.fetchWalletData,
            );
          }

          final walletData = walletProvider.walletData;
          if (walletData == null) {
            return _WalletMessageState(
              title: 'Wallet unavailable',
              message: 'No wallet data has been returned yet.',
              actionLabel: 'Refresh',
              onPressed: walletProvider.fetchWalletData,
            );
          }

          final transactions = walletData.transactions;
          final transactionNet = transactions.fold<double>(
            0,
            (sum, transaction) => sum + transaction.amount,
          );

          final currentMonth = DateFormat('MMMM y').format(DateTime.now());
          final previousMonth = DateFormat('MMM').format(
            DateTime(DateTime.now().year, DateTime.now().month - 1),
          );

          return RefreshIndicator(
            onRefresh: walletProvider.refreshData,
            child: CustomScrollView(
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
                      AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Wallet',
                                    style: theme.textTheme.displaySmall?.copyWith(
                                      fontSize: 32,
                                    ),
                                  ),
                
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: walletProvider.refreshData,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _WalletBalanceCard(
                          title: 'Available balance',
                          amount: walletData.walletBalance.balance,
                          subtitle: 'Tracked wallet amount',
                          icon: Icons.account_balance_wallet_rounded,
                          colors: const [
                            AppColors.seed,
                            AppColors.accent,
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: _WalletStatCard(
                                title: 'Transaction net',
                                value: transactionNet,
                                icon: Icons.swap_vert_rounded,
                                accentColor: const Color(0xFF4B6ED6),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _WalletStatCard(
                                title: 'Expense ($previousMonth)',
                                value: walletProvider.lastMonthExpense,
                                icon: Icons.calendar_month_rounded,
                                accentColor: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Quick actions',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: _WalletActionCard(
                                icon: Icons.add_circle_outline_rounded,
                                label: 'Add funds',
                                accentColor: AppColors.success,
                                onTap: () => _showWalletAmountDialog(
                                  title: 'Add funds',
                                  description:
                                      'Increase the wallet balance by the amount you enter.',
                                  confirmLabel: 'Add',
                                  onSubmit: (amount) => _processWalletAction(
                                    actionLabel: 'Add funds',
                                    action: () => context
                                        .read<WalletProvider>()
                                        .topUpWallet(amount),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _WalletActionCard(
                                icon: Icons.sync_alt_rounded,
                                label: 'Set balance',
                                accentColor: AppColors.warning,
                                onTap: () => _showWalletAmountDialog(
                                  title: 'Set wallet balance',
                                  description:
                                      'Replace the current wallet balance with a new amount.',
                                  confirmLabel: 'Update',
                                  onSubmit: (amount) => _processWalletAction(
                                    actionLabel: 'Update balance',
                                    action: () => context
                                        .read<WalletProvider>()
                                        .updateWalletBalance(amount),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _WalletActionCard(
                                icon: Icons.refresh_rounded,
                                label: 'Reset',
                                accentColor: AppColors.danger,
                                onTap: _confirmReset,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          children: [
                            Text(
                              'Recent wallet transactions',
                              style: theme.textTheme.titleLarge,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
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
                if (transactions.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _WalletEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      120,
                    ),
                    sliver: SliverList.separated(
                      itemCount: transactions.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.sm,
                            ),
                            leading: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.payments_outlined,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              transaction.description.isNotEmpty
                                  ? transaction.description
                                  : 'Wallet movement',
                              style: theme.textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              DateFormat('MMM d, y • h:mm a')
                                  .format(transaction.date),
                              style: theme.textTheme.bodyMedium,
                            ),
                            trailing: Text(
                              '\$${transaction.amount.toStringAsFixed(2)}',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WalletBalanceCard extends StatelessWidget {
  final String title;
  final double amount;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;

  const _WalletBalanceCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletStatCard extends StatelessWidget {
  final String title;
  final double value;
  final IconData icon;
  final Color accentColor;

  const _WalletStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '\$${value.toStringAsFixed(2)}',
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  const _WalletActionCard({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletLoadingState extends StatelessWidget {
  const _WalletLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: const [
        _WalletSkeletonBlock(height: 140),
        SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: _WalletSkeletonBlock(height: 120)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: _WalletSkeletonBlock(height: 120)),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: _WalletSkeletonBlock(height: 118)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: _WalletSkeletonBlock(height: 118)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: _WalletSkeletonBlock(height: 118)),
          ],
        ),
      ],
    );
  }
}

class _WalletSkeletonBlock extends StatelessWidget {
  final double height;

  const _WalletSkeletonBlock({
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
    );
  }
}

class _WalletMessageState extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onPressed;

  const _WalletMessageState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: onPressed,
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletEmptyState extends StatelessWidget {
  const _WalletEmptyState();

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
                  Icons.account_balance_wallet_outlined,
                  color: scheme.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No wallet transactions yet',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Use the actions above to add funds or set your first wallet balance.',
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
