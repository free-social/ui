import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_radii.dart';
import '../providers/sport_provider.dart';
import '../models/sport_model.dart';

class SportDetailScreen extends StatefulWidget {
  final String sportId;

  const SportDetailScreen({super.key, required this.sportId});

  @override
  State<SportDetailScreen> createState() => _SportDetailScreenState();
}

class _SportDetailScreenState extends State<SportDetailScreen> {
  SportModel? _sport;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSport();
  }

  Future<void> _loadSport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final provider = context.read<SportProvider>();
    final result = await provider.getSportById(widget.sportId);

    if (!mounted) return;
    setState(() {
      _sport = result;
      _isLoading = false;
      if (result == null) _error = 'Could not load activity details.';
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
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Text(
                      'Activity Detail',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError(theme, scheme)
                    : _buildDetail(theme, scheme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme, ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 56, color: AppColors.danger.withValues(alpha: 0.6)),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _error ?? 'Unknown error',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton.icon(
            onPressed: _loadSport,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(ThemeData theme, ColorScheme scheme, bool isDark) {
    final sport = _sport!;
    final dateStr = DateFormat('EEEE, MMMM dd, yyyy').format(sport.date);
    final timeStr = DateFormat('hh:mm a').format(sport.date);
    final categoryColor = _categoryColor(sport.category);
    final categoryIcon = _categoryIcon(sport.category);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          // ── Distance hero card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  categoryColor,
                  categoryColor.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: [
                BoxShadow(
                  color: categoryColor.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(categoryIcon, color: Colors.white, size: 40),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${sport.length.toStringAsFixed(2)} km',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    sport.category.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Info rows ──
          _InfoCard(
            isDark: isDark,
            children: [
              _InfoRow(
                icon: Icons.calendar_today_rounded,
                iconColor: const Color(0xFF3B82F6),
                label: 'Date',
                value: dateStr,
              ),
              _divider(scheme),
              _InfoRow(
                icon: Icons.access_time_rounded,
                iconColor: const Color(0xFF8B5CF6),
                label: 'Time',
                value: timeStr,
              ),
              _divider(scheme),
              _InfoRow(
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFF10B981),
                label: 'Duration',
                value: '${sport.duration} min',
              ),
              if (sport.note != null && sport.note!.trim().isNotEmpty) ...[
                _divider(scheme),
                _InfoRow(
                  icon: Icons.note_alt_outlined,
                  iconColor: const Color(0xFF06B6D4),
                  label: 'Note',
                  value: sport.note!,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme scheme) {
    return Divider(
      height: 1,
      indent: 72,
      endIndent: AppSpacing.lg,
      color: scheme.onSurface.withValues(alpha: 0.08),
    );
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

// ── Reusable info card ──
class _InfoCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;

  const _InfoCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

// ── Single info row ──
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 2,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.45),
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
