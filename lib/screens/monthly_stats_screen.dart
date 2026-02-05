import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
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
      await provider.fetchMonthlyExpenses(_currentDate.month, _currentDate.year);
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
    final Color cardColor = theme.cardColor; 
    final Color progressBgColor = isDark ? Colors.grey[800]! : const Color(0xFFF2F4F7);
    final Color scaffoldBg = theme.scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: scaffoldBg, 
        title: Text(
          "Spending Summary",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) return const Center(child: CircularProgressIndicator());

          final dynamic rawData = _isDailyView 
              ? provider.dailySummary 
              : provider.monthlySummary;

          List<dynamic> rawTransactions = [];
          if (rawData is Map && rawData.containsKey('data')) {
            rawTransactions = rawData['data']['transactions'] ?? [];
          }

          Map<String, double> categoryTotals = {};
          double totalSpent = 0.0;
          
          for (var tx in rawTransactions) {
            final double amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
            final String category = tx['category']?.toString().toLowerCase() ?? 'other';
            
            if (amount > 0) {
              totalSpent += amount;
              categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
            }
          }

          List<Map<String, dynamic>> uiList = categoryTotals.entries
              .map((e) => {
                'category': e.key, 
                'amount': e.value,
                'color': _getCategoryColor(e.key),
              }).toList();
          uiList.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

          // ✅ Wrapped in RefreshIndicator
          return RefreshIndicator(
            onRefresh: _fetchData,
            color: kPrimaryColor,
            child: Column(
              children: [
                _buildToggleBar(cardColor, textColor),
                _buildDateSelector(textColor),
                const SizedBox(height: 20),
                
                _buildDynamicRing(uiList, totalSpent, textColor, subTextColor),
                
                const SizedBox(height: 40),
                _buildCategoryHeader(textColor),
                
                // ✅ Using Expanded with LayoutBuilder to handle empty states 
                // while keeping pull-to-refresh working
                Expanded(
                  child: uiList.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: 200, // Space to push empty state down
                              child: _buildEmptyState(subTextColor),
                            )
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: uiList.length,
                          itemBuilder: (context, index) {
                            final item = uiList[index];
                            return _buildStatRow(
                              item['category'], 
                              item['amount'], 
                              totalSpent, 
                              item['color'],
                              textColor,
                              subTextColor,
                              progressBgColor
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

  // --- WIDGETS ---

  Widget _buildToggleBar(Color bgColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      height: 50,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ]
      ),
      child: Row(
        children: [
          _buildToggleButton("Daily", true),
          _buildToggleButton("Monthly", false),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isDailyBtn) {
    final bool isActive = _isDailyView == isDailyBtn;
    return Expanded(
      child: GestureDetector(
        onTap: () => _toggleView(isDailyBtn),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isActive ? kPrimaryColor : Colors.transparent, 
            borderRadius: BorderRadius.circular(22)
          ),
          child: Center(
            child: Text(
              label, 
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey, 
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal
              )
            )
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

    if (_isDailyView) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            label, 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: kPrimaryColor), 
          onPressed: () => _changeDate(-1)
        ),
        Text(
          label, 
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)
        ),
        IconButton(
          icon: Icon(Icons.chevron_right, color: kPrimaryColor), 
          onPressed: () => _changeDate(1)
        ),
      ],
    );
  }

  Widget _buildDynamicRing(List<Map<String, dynamic>> categories, double total, Color mainText, Color subText) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CustomPaint(
              painter: MultiSegmentPainter(
                categories: categories,
                total: total,
                strokeWidth: 16,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Total Spent", style: TextStyle(color: subText, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                "\$${NumberFormat("#,##0").format(total)}", 
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: mainText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String category, double amount, double total, Color color, Color mainText, Color subText, Color progressBg) {
    final percentage = total == 0 ? 0.0 : (amount / total);
    final displayCategory = category.isNotEmpty 
        ? category[0].toUpperCase() + category.substring(1) 
        : category;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 45, height: 45,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1), 
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
                      displayCategory, 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: mainText),
                    ),
                    Text(_getCategorySub(category), style: TextStyle(color: subText, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "\$${NumberFormat("#,##0").format(amount)}", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: mainText),
                  ),
                  Text("${(percentage * 100).toInt()}%", style: TextStyle(color: subText, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 6,
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
            style: TextStyle(color: textColor)
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Categories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          Text("See all", style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food': return Icons.local_cafe;
      case 'travel': return Icons.directions_car;
      case 'shopping': return Icons.shopping_bag;
      case 'bills': return Icons.receipt_long;
      case 'rent': return Icons.home;
      case 'other': return Icons.category;
      default: return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food': return Colors.teal;
      case 'travel': return Colors.orange;
      case 'shopping': return Colors.purple;
      case 'bills': return const Color(0xFFFF5252);
      case 'rent': return Colors.indigo;
      case 'other': return Colors.blueGrey;
      default: return Colors.blueGrey;
    }
  }

  String _getCategorySub(String category) {
    switch (category.toLowerCase()) {
      case 'travel': return 'Commute & Trips';
      case 'food': return 'Groceries & Dining';
      case 'bills': return 'Utilities & Fees';
      case 'shopping': return 'Personal Items';
      case 'rent': return 'Housing & Rent';
      default: return 'General';
    }
  }
}

class MultiSegmentPainter extends CustomPainter {
  final List<Map<String, dynamic>> categories;
  final double total;
  final double strokeWidth;

  MultiSegmentPainter({required this.categories, required this.total, required this.strokeWidth});

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