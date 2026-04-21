import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../core/theme/app_colors.dart';
import '../core/theme/app_radii.dart';
import '../core/theme/app_spacing.dart';
import '../providers/expense_provider.dart';

class MonthlyStatsScreen extends StatefulWidget {
  const MonthlyStatsScreen({super.key});

  @override
  State<MonthlyStatsScreen> createState() => _MonthlyStatsScreenState();
}

class _MonthlyStatsScreenState extends State<MonthlyStatsScreen> {
  bool _isDailyView = true;
  DateTime _currentDate = DateTime.now();

  final Color kPrimaryColor = const Color(0xFF00BFA5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
  }

  // ✅ Changed to return Future for RefreshIndicator
  Future<void> _fetchData() async {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);

    if (_isDailyView) {
      await provider.fetchDailyExpenses(_currentDate);
    } else {
      await provider.fetchMonthlyExpenses(
        _currentDate.month,
        _currentDate.year,
      );
    }
  }

  void _changeDate(int add) {
    setState(() {
      if (_isDailyView) {
        _currentDate = _currentDate.add(Duration(days: add));
      } else {
        _currentDate = DateTime(_currentDate.year, _currentDate.month + add);
      }
    });
    _fetchData();
  }

  void _toggleView(bool isDaily) {
    if (_isDailyView == isDaily) return;
    setState(() {
      _isDailyView = isDaily;
      _currentDate = DateTime.now();
    });
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey;
    final Color cardColor = theme.colorScheme.surface;
    final Color progressBgColor = isDark
        ? Colors.grey[800]!
        : const Color(0xFFF2F4F7);
    final Color scaffoldBg = theme.scaffoldBackgroundColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: Builder(
          builder: (context) {
            final isStatsLoading = context.select<ExpenseProvider, bool>(
              (provider) => provider.isStatsLoading,
            );
            final rawData = context.select<ExpenseProvider, dynamic>(
              (provider) =>
                  _isDailyView ? provider.dailySummary : provider.monthlySummary,
            );

            List<dynamic> rawTransactions = [];
            if (rawData is Map && rawData.containsKey('data')) {
              rawTransactions = rawData['data']['transactions'] ?? [];
            }

            Map<String, double> categoryTotals = {};
            double totalSpent = 0.0;

            for (var tx in rawTransactions) {
              final double amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
              final String category =
                  tx['category']?.toString().toLowerCase() ?? 'other';

              if (amount > 0) {
                totalSpent += amount;
                categoryTotals[category] =
                    (categoryTotals[category] ?? 0) + amount;
              }
            }

            List<Map<String, dynamic>> uiList = categoryTotals.entries
                .map(
                  (e) => {
                    'category': e.key,
                    'amount': e.value,
                    'color': _getCategoryColor(e.key),
                  },
                )
                .toList();
            uiList.sort(
              (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 250.0,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [theme.colorScheme.primary, AppColors.accent],
                        ),
                      ),
                    ),

                    Positioned(
                      left: AppSpacing.xl,
                      right: AppSpacing.xl,
                      bottom: -80.0,
                      child: isStatsLoading
                          ? _buildSkeletonOverviewCard(cardColor, isDark)
                          : _buildOverviewCard(
                              categories: uiList,
                              totalSpent: totalSpent,
                              textColor: textColor,
                              subTextColor: subTextColor,
                              cardColor: cardColor,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 80.0 + AppSpacing.xl),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchData,
                    color: kPrimaryColor,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, 120),
                      children: [
                        _buildCategoryHeader(textColor, subTextColor, uiList.length),
                        const SizedBox(height: AppSpacing.md),
                        if (isStatsLoading)
                          ...List.generate(
                            4,
                            (_) => _buildSkeletonCategoryRow(
                              isDark ? Colors.grey[800]! : Colors.grey[300]!,
                              highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                              cardColor: cardColor,
                            ),
                          )
                        else if (uiList.isEmpty)
                          SizedBox(height: 180, child: _buildEmptyState(subTextColor))
                        else
                          ...uiList.map(
                            (item) => _buildStatRow(
                              item['category'],
                              item['amount'],
                              totalSpent,
                              item['color'],
                              textColor,
                              subTextColor,
                              progressBgColor,
                              cardColor,
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

  // --- WIDGETS ---

  Widget _buildToggleBar(Color bgColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 0),
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _buildToggleButton("Daily", true, textColor),
          _buildToggleButton("Monthly", false, textColor),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isDailyBtn, Color textColor) {
    final bool isActive = _isDailyView == isDailyBtn;
    return Expanded(
      child: GestureDetector(
        onTap: () => _toggleView(isDailyBtn),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? kPrimaryColor : textColor,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(Color textColor) {
    String label;
    if (_isDailyView) {
      label = DateFormat('EEE, MMM d').format(_currentDate);
    } else {
      label = DateFormat('MMMM yyyy').format(_currentDate);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDateChevron(
          icon: Icons.chevron_left,
          onTap: () => _changeDate(-1),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(width: 12),
        _buildDateChevron(
          icon: Icons.chevron_right,
          onTap: () => _changeDate(1),
        ),
      ],
    );
  }

  Widget _buildDateChevron({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildOverviewCard({
    required List<Map<String, dynamic>> categories,
    required double totalSpent,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
  }) {
    final topCategory = categories.isEmpty ? null : categories.first;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildDynamicRing(
                categories,
                totalSpent,
                textColor,
                subTextColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryMetric(
                      label: 'Total spent',
                      value: '\$${NumberFormat("#,##0").format(totalSpent)}',
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryMetric(
                      label: 'Top category',
                      value: topCategory == null
                          ? 'No data'
                          : _formatCategoryName(
                              topCategory['category'] as String,
                            ),
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),      
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: subTextColor, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicRing(
    List<Map<String, dynamic>> categories,
    double total,
    Color mainText,
    Color subText,
  ) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: CustomPaint(
              painter: MultiSegmentPainter(
                categories: categories,
                total: total,
                strokeWidth: 14,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Total Spent",
                style: TextStyle(color: subText, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                "\$${NumberFormat.compactCurrency(symbol: '', decimalDigits: 0).format(total)}",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: mainText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    String category,
    double amount,
    double total,
    Color color,
    Color mainText,
    Color subText,
    Color progressBg,
    Color cardColor,
  ) {
    final percentage = total == 0 ? 0.0 : (amount / total);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getCategoryIcon(category), color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatCategoryName(category),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: mainText,
                      ),
                    ),
                    Text(
                      _getCategorySub(category),
                      style: TextStyle(color: subText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "\$${NumberFormat("#,##0").format(amount)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: mainText,
                    ),
                  ),
                  Text(
                    "${(percentage * 100).toInt()}%",
                    style: TextStyle(color: subText, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 7,
              backgroundColor: progressBg,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(
            _isDailyView ? "No spending today" : "No spending this month",
            style: TextStyle(color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(
    Color textColor,
    Color subTextColor,
    int itemCount,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Categories",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                itemCount == 0
                    ? 'No category data yet'
                    : '$itemCount categories tracked',
                style: TextStyle(color: subTextColor, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCategoryName(String category) {
    return category.isNotEmpty
        ? category[0].toUpperCase() + category.substring(1)
        : category;
  }

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

  String _getCategorySub(String category) {
    switch (category.toLowerCase()) {
      case 'travel':
        return 'Commute & Trips';
      case 'food':
        return 'Groceries & Dining';
      case 'bills':
        return 'Utilities & Fees';
      case 'shopping':
        return 'Personal Items';
      case 'rent':
        return 'Housing & Rent';
      default:
        return 'General';
    }
  }

  // Skeleton Loading Widgets
  Widget _buildSkeletonOverviewCard(Color cardColor, bool isDark) {
    final shimmerBaseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final shimmerHighlightColor = isDark
        ? Colors.grey[700]!
        : Colors.grey[100]!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  shimmerBaseColor,
                  shimmerHighlightColor,
                  shimmerBaseColor,
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                _buildSkeletonSummaryLine(shimmerBaseColor, 90, 12),
                const SizedBox(height: 8),
                _buildSkeletonSummaryLine(shimmerBaseColor, 120, 20),
                const SizedBox(height: 14),
                _buildSkeletonSummaryLine(shimmerBaseColor, 80, 12),
                const SizedBox(height: 8),
                _buildSkeletonSummaryLine(shimmerBaseColor, 100, 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonSummaryLine(Color color, double width, double height) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _buildSkeletonDateChevron(Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _buildSkeletonCategoryRow(
    Color baseColor, {
    required Color highlightColor,
    required Color cardColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [baseColor, highlightColor, baseColor],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 100,
                      height: 12,
                      decoration: BoxDecoration(
                        color: baseColor.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 70,
                    height: 16,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 40,
                    height: 12,
                    decoration: BoxDecoration(
                      color: baseColor.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: double.infinity,
              height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [baseColor, highlightColor, baseColor],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MultiSegmentPainter extends CustomPainter {
  final List<Map<String, dynamic>> categories;
  final double total;
  final double strokeWidth;

  MultiSegmentPainter({
    required this.categories,
    required this.total,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;

    for (var cat in categories) {
      final sweepAngle = (cat['amount'] / total) * 2 * math.pi;

      final paint = Paint()
        ..color = cat['color']
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant MultiSegmentPainter oldDelegate) => true;
}
