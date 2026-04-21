import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
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
                    enabled: !isLoading,
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
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final amount = double.tryParse(
                            controller.text.trim(),
                          );
                          if (amount == null || amount < 0) {
                            return;
                          }

                          setState(() => isLoading = true);
                          await onSubmit(amount);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(confirmLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmReset() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              title: const Text('Reset wallet?'),
              content: const Text(
                'This will set the wallet balance to \$0.00.',
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() => isLoading = true);
                          await _processWalletAction(
                            actionLabel: 'Reset wallet',
                            action: () => context
                                .read<WalletProvider>()
                                .updateWalletBalance(0.0),
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Reset'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _processWalletAction({
    required String actionLabel,
    required Future<void> Function() action,
  }) async {
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
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
            ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Consumer<WalletProvider>(
          builder: (context, walletProvider, child) {
            if (walletProvider.isLoading && walletProvider.walletData == null) {
              return const SafeArea(child: _WalletLoadingState());
            }

            if (walletProvider.error != null &&
                walletProvider.walletData == null) {
              return SafeArea(
                child: _WalletMessageState(
                  title: 'Could not load wallet',
                  message: walletProvider.error!,
                  actionLabel: 'Try again',
                  onPressed: walletProvider.fetchWalletData,
                ),
              );
            }

            final walletData = walletProvider.walletData;
            if (walletData == null) {
              return SafeArea(
                child: _WalletMessageState(
                  title: 'Wallet unavailable',
                  message: 'No wallet data has been returned yet.',
                  actionLabel: 'Refresh',
                  onPressed: walletProvider.fetchWalletData,
                ),
              );
            }

            final transactions = walletData.transactions;
            final transactionNet = transactions.fold<double>(
              0,
              (sum, transaction) => sum + transaction.amount,
            );

            // final currentMonth = DateFormat('MMMM y').format(DateTime.now());
            final previousMonth = DateFormat(
              'MMM',
            ).format(DateTime(DateTime.now().year, DateTime.now().month - 1));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Fixed Gradient Header ──
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
                        child: Row(children: [
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppSpacing.xl,
                      right: AppSpacing.xl,
                      bottom: -56.0,
                      child: _WalletBalanceCard(
                        title: 'Available balance',
                        amount: walletData.walletBalance.balance,
                        subtitle: 'Tracked wallet amount',
                        icon: Icons.account_balance_wallet_rounded,
                        isDark: isDark,
                        scheme: scheme,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 56.0 + AppSpacing.xl),

                // ── Scrollable Body ──
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: walletProvider.refreshData,
                    color: scheme.primary,
                    displacement: 20,
                    child: CustomScrollView(
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
                              AppSpacing.xl,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                  'Actions',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _WalletActionCard(
                                        icon: Icons.add_circle_outline_rounded,
                                        label: 'Add to wallet',
                                        accentColor: AppColors.success,
                                        isHorizontal: true,
                                        onTap: () => _showWalletAmountDialog(
                                          title: 'Add to wallet',
                                          description:
                                              'Increase the wallet balance by the amount you enter.',
                                          confirmLabel: 'Add',
                                          onSubmit: (amount) => _processWalletAction(
                                            actionLabel: 'Add',
                                            action: () => context
                                                .read<WalletProvider>()
                                                .topUpWallet(amount),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _WalletActionCard(
                                        icon: Icons.sync_alt_rounded,
                                        label: 'Set',
                                        accentColor: AppColors.warning,
                                        isHorizontal: true,
                                        onTap: () => _showWalletAmountDialog(
                                          title: 'Set',
                                          description:
                                              'Replace the current wallet balance with a new amount.',
                                          confirmLabel: 'Update',
                                          onSubmit: (amount) =>
                                              _processWalletAction(
                                                actionLabel: 'Update balance',
                                                action: () => context
                                                    .read<WalletProvider>()
                                                    .updateWalletBalance(
                                                      amount,
                                                    ),
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
                                        isHorizontal: true,
                                        onTap: _confirmReset,
                                      ),
                                    ),
                                  ],
                                ),
                              
                                const SizedBox(height: AppSpacing.md),
                              ],
                            ),
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

class _WalletBalanceCard extends StatelessWidget {
  final String title;
  final double amount;
  final String subtitle;
  final IconData icon;
  final bool isDark;
  final ColorScheme scheme;

  const _WalletBalanceCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
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
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: theme.textTheme.displaySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: textColor.withValues(alpha: 0.6),
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
  final bool isHorizontal;

  const _WalletActionCard({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final double iconBoxSize = isHorizontal ? 38 : 52;
    final double iconSize = isHorizontal ? 20 : 24;
    final double iconPadding = isHorizontal ? 12 : 16;
    
    List<Widget> content = [
      Container(
        width: iconBoxSize,
        height: iconBoxSize,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(iconPadding),
        ),
        child: Icon(icon, color: accentColor, size: iconSize),
      ),
      SizedBox(
        width: isHorizontal ? AppSpacing.md : 0,
        height: isHorizontal ? 0 : AppSpacing.md,
      ),
      Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    ];

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: isHorizontal
              ? const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm)
              : const EdgeInsets.all(AppSpacing.lg),
          child: isHorizontal
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: content,
                )
              : Column(
                  children: content,
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

  const _WalletSkeletonBlock({required this.height});

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
                ElevatedButton(onPressed: onPressed, child: Text(actionLabel)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

