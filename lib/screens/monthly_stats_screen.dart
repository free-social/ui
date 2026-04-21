import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme/app_colors.dart';
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
    if (_isDailyView == isDaily) {
      return;
    }
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
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
            ),
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: Builder(
          builder: (context) {
            final isStatsLoading = context.select<ExpenseProvider, bool>(
              (provider) => provider.isStatsLoading,
            );
            final rawData = context.select<ExpenseProvider, dynamic>(
              (provider) => _isDailyView
                  ? provider.dailySummary
                  : provider.monthlySummary,
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
              (a, b) =>
                  (b['amount'] as double).compareTo(a['amount'] as double),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 180.0,
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
                      bottom: -56.0,
                      child: isStatsLoading
                          ? _buildSkeletonOverviewCard(cardColor, isDark)
                          : _buildOverviewCard(
                              categories: uiList,
                              totalSpent: totalSpent,
                              textColor: textColor,
                              subTextColor: subTextColor,
                              cardColor: cardColor,
                              rawTransactions: rawTransactions,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 56.0 + AppSpacing.xl),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchData,
                    color: kPrimaryColor,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        0,
                        AppSpacing.xl,
                        120,
                      ),
                      children: [
                        _buildToggleBar(
                          cardColor,
                          textColor,
                          isDark ? Colors.grey[800]! : Colors.grey[200]!,
                        ),
                        const SizedBox(height: 24),
                        _buildDateSelector(textColor, cardColor),
                        const SizedBox(height: 32),
                        _buildCategoryHeader(
                          textColor,
                          subTextColor,
                          uiList.length,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (isStatsLoading)
                          ...List.generate(
                            4,
                            (_) => _buildSkeletonCategoryRow(
                              isDark ? Colors.grey[800]! : Colors.grey[300]!,
                              highlightColor: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[100]!,
                              cardColor: cardColor,
                            ),
                          )
                        else if (uiList.isEmpty)
                          SizedBox(
                            height: 180,
                            child: _buildEmptyState(subTextColor),
                          )
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

  Widget _buildToggleBar(Color cardColor, Color textColor, Color activeColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      height: 48,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildToggleButton("Daily", true, textColor, activeColor),
          _buildToggleButton("Monthly", false, textColor, activeColor),
        ],
      ),
    );
  }

  Widget _buildToggleButton(
    String label,
    bool isDailyBtn,
    Color textColor,
    Color activeColor,
  ) {
    final bool isActive = _isDailyView == isDailyBtn;
    return Expanded(
      child: GestureDetector(
        onTap: () => _toggleView(isDailyBtn),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
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

  Widget _buildDateSelector(Color textColor, Color btnColor) {
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
          btnColor: btnColor,
          iconColor: textColor,
        ),
        const SizedBox(width: 16),
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(width: 16),
        _buildDateChevron(
          icon: Icons.chevron_right,
          onTap: () => _changeDate(1),
          btnColor: btnColor,
          iconColor: textColor,
        ),
      ],
    );
  }

  Widget _buildDateChevron({
    required IconData icon,
    required VoidCallback onTap,
    required Color btnColor,
    required Color iconColor,
  }) {
    return Material(
      color: btnColor,
      borderRadius: BorderRadius.circular(14),
      shadowColor: Colors.black.withValues(alpha: 0.05),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: iconColor, size: 24),
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
    required List<dynamic> rawTransactions,
  }) {
    final topCategory = categories.isEmpty ? null : categories.first;

    List<FlSpot> spots = [];
    double maxY = 0;
    if (rawTransactions.isNotEmpty) {
      Map<int, double> timeGroups = {};
      for (var tx in rawTransactions) {
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final dateStr = tx['date'] ?? tx['createdAt'];
        if (dateStr != null && amount > 0) {
          DateTime dt =
              DateTime.tryParse(dateStr.toString())?.toLocal() ??
              DateTime.now();
          int key = _isDailyView ? dt.hour : dt.day;
          timeGroups[key] = (timeGroups[key] ?? 0) + amount;
        }
      }

      int startKey = _isDailyView ? 0 : 1;
      int endKey = _isDailyView
          ? 23
          : DateTime(_currentDate.year, _currentDate.month + 1, 0).day;

      for (int i = startKey; i <= endKey; i++) {
        final amt = timeGroups[i] ?? 0.0;
        spots.add(FlSpot(i.toDouble(), amt));
        if (amt > maxY) {
          maxY = amt;
        }
      }
    }

    if (maxY == 0) {
      maxY = 100;
    }
    double maxX = _isDailyView
        ? 23
        : DateTime(_currentDate.year, _currentDate.month + 1, 0).day.toDouble();
    if (spots.isEmpty) {
      spots = [const FlSpot(0, 0), FlSpot(maxX, 0)];
    }

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryMetric(
                label: 'Total spent',
                value: '\$${NumberFormat("#,##0").format(totalSpent)}',
                textColor: textColor,
                subTextColor: subTextColor,
                crossAxisAlignment: CrossAxisAlignment.start,
              ),
              if (topCategory != null)
                _buildSummaryMetric(
                  label: 'Top category',
                  value: _formatCategoryName(topCategory['category'] as String),
                  textColor: textColor,
                  subTextColor: subTextColor,
                  crossAxisAlignment: CrossAxisAlignment.end,
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 60,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        // For daily view we show some hour labels, monthly we show days
                        if (_isDailyView && (value % 6 != 0)) {
                          return const SizedBox.shrink();
                        }
                        if (!_isDailyView && (value % 5 != 0 && value != 1)) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(color: subTextColor, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: _isDailyView ? 0 : 1,
                maxX: maxX,
                minY: 0,
                maxY: maxY * 1.2,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => textColor.withValues(alpha: 0.8),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        return LineTooltipItem(
                          '\$${touchedSpot.y.toStringAsFixed(0)}',
                          TextStyle(
                            color: cardColor,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: kPrimaryColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          kPrimaryColor.withValues(alpha: 0.3),
                          kPrimaryColor.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSkeletonSummaryLine(shimmerBaseColor, 80, 12),
                  const SizedBox(height: 4),
                  _buildSkeletonSummaryLine(shimmerBaseColor, 120, 20),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildSkeletonSummaryLine(
                    shimmerBaseColor,
                    80,
                    12,
                    alignment: Alignment.centerRight,
                  ),
                  const SizedBox(height: 4),
                  _buildSkeletonSummaryLine(
                    shimmerBaseColor,
                    100,
                    16,
                    alignment: Alignment.centerRight,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 60,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 10,
                lineTouchData: const LineTouchData(
                  enabled: false,
                ), // disable tooltips for skeleton
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 3),
                      FlSpot(1, 5),
                      FlSpot(2, 4),
                      FlSpot(3, 8),
                      FlSpot(4, 5),
                      FlSpot(5, 7),
                      FlSpot(6, 6),
                    ],
                    isCurved: true,
                    color: shimmerHighlightColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          shimmerBaseColor.withValues(alpha: 0.5),
                          shimmerBaseColor.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonSummaryLine(
    Color color,
    double width,
    double height, {
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Align(
      alignment: alignment,
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
