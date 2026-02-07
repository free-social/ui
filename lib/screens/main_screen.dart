import 'package:flutter/material.dart';
import 'home_view.dart';
import 'monthly_stats_screen.dart';
import 'user_profile.dart';
import 'transaction_form_screen.dart';
// import 'contact_screen.dart'; // ✅ 1. IMPORT THIS
import 'wallet_screen.dart';
// ឬ import 'package:mobileproject/ui/screens/wallet_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _screens = [
    const HomeView(), // Index 0
    const MonthlyStatsScreen(), // Index 1
    const WalletScreen(), // ✅ 2. USE THE REAL SCREEN HERE
    const UserProfileScreen(), // Index 3
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TransactionFormScreen(),
            ),
          );
        },
        backgroundColor: theme.primaryColor,
        elevation: 4,
        shape: const CircleBorder(), // Circle Button
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: theme.cardColor,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', 0, isDark),
              _buildNavItem(Icons.bar_chart, 'Stats', 1, isDark),

              const SizedBox(width: 40), // Space for FAB

              _buildNavItem(
                Icons.account_balance_wallet, // Icon Wallet
                'Wallet', // ឈ្មោះថ្មី
                2, // Index 2
                isDark, // ត្រូវដាក់ isDark តាម function របស់អ្នក
              ),
              _buildNavItem(Icons.person, 'Profile', 3, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDark) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected
                ? theme.primaryColor
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? theme.primaryColor
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
