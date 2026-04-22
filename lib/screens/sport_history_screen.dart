import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_radii.dart';
import '../providers/sport_provider.dart';
import '../models/sport_model.dart';
import 'sport_detail_screen.dart';

class SportHistoryScreen extends StatefulWidget {
  const SportHistoryScreen({super.key});

  @override
  State<SportHistoryScreen> createState() => _SportHistoryScreenState();
}

class _SportHistoryScreenState extends State<SportHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SportProvider>().fetchSports(page: 1, forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Gradient header ──
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, AppColors.accent],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Text(
                          'Sport History',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.lg,
                        top: AppSpacing.xs,
                      ),
                      child: Text(
                        'All your recorded activities',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── List body ──
          Expanded(
            child: Consumer<SportProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.sports.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.sports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_run_rounded,
                            size: 64,
                            color: scheme.onSurface.withValues(alpha: 0.2)),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'No activities yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Start tracking to see your history here',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Group sports by month
                final grouped = _groupByMonth(provider.sports);

                return RefreshIndicator(
                  onRefresh: () => provider.fetchSports(
                    page: 1,
                    forceRefresh: true,
                  ),
                  color: scheme.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      100,
                    ),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final entry = grouped.entries.elementAt(index);
                      final monthLabel = entry.key;
                      final items = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (index > 0) const SizedBox(height: AppSpacing.lg),
                          // Month header
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.xs,
                              bottom: AppSpacing.sm,
                            ),
                            child: Text(
                              monthLabel.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: scheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                          // Month card
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurface
                                  : Colors.white,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.lg),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                      alpha: isDark ? 0.18 : 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.lg),
                              child: Column(
                                children: items
                                    .asMap()
                                    .entries
                                    .map((e) => _buildSportTile(
                                          context,
                                          e.value,
                                          showDivider:
                                              e.key < items.length - 1,
                                        ))
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSportTile(
    BuildContext context,
    SportModel sport, {
    bool showDivider = true,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateStr = DateFormat('MMM dd, yyyy – hh:mm a').format(sport.date);

    final categoryIcon = _categoryIcon(sport.category);
    final categoryColor = _categoryColor(sport.category);

    return Column(
      children: [
        ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SportDetailScreen(sportId: sport.id),
              ),
            );
          },
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(categoryIcon, color: categoryColor, size: 22),
          ),
          title: Row(
            children: [
              Text(
                '${sport.length.toStringAsFixed(2)} km',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  sport.category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: categoryColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$dateStr • ${sport.duration} min',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: scheme.onSurface.withValues(alpha: 0.28),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 72,
            endIndent: AppSpacing.lg,
            color: scheme.onSurface.withValues(alpha: 0.08),
          ),
      ],
    );
  }

  Map<String, List<SportModel>> _groupByMonth(List<SportModel> sports) {
    final Map<String, List<SportModel>> grouped = {};
    for (final sport in sports) {
      final key = DateFormat('MMMM yyyy').format(sport.date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(sport);
    }
    return grouped;
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'swimming':
        return Icons.pool_rounded;
      case 'walking':
        return Icons.directions_walk_rounded;
      case 'jogging':
        return Icons.directions_run_rounded;
      default:
        return Icons.directions_run_rounded;
    }
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'cycling':
        return const Color(0xFF3B82F6);
      case 'swimming':
        return const Color(0xFF06B6D4);
      case 'walking':
        return const Color(0xFF8B5CF6);
      case 'jogging':
        return const Color(0xFF10B981);
      default:
        return AppColors.success;
    }
  }
}
