import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import 'chat_screen.dart';
import 'home_view.dart';
import 'monthly_stats_screen.dart';
import 'transaction_form_screen.dart';
import 'user_profile.dart';
import 'wallet_screen.dart';
import 'ai_chat_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final PageController _pageController = PageController();
  int _selectedIndex = 0;

  static const List<_NavItem> _items = [
    _NavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      screen: HomeView(),
    ),
    _NavItem(
      label: 'Stats',
      icon: Icons.query_stats_outlined,
      selectedIcon: Icons.query_stats_rounded,
      screen: MonthlyStatsScreen(),
    ),
    _NavItem(
      label: 'Wallet',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      screen: WalletScreen(),
    ),
    _NavItem(
      label: 'Chat',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      screen: ChatScreen(),
      isBeta: true,
    ),
    _NavItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      screen: UserProfileScreen(),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openTransactionForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Stack(
      children: [
        // ── Main Scaffold ──────────────────────────────────────────────
        Scaffold(
          extendBody: true,
          body: PageView(
            controller: _pageController,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (index) {
              if (_selectedIndex != index) {
                setState(() => _selectedIndex = index);
              }
            },
            children: _items.map((item) => item.screen).toList(),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _openTransactionForm,
            elevation: 0,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            shape: const CircleBorder(),
            child: const Icon(Icons.add_rounded),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          bottomNavigationBar: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.65),
                  border: Border(
                    top: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: NavigationBarTheme(
                      data: NavigationBarThemeData(
                        backgroundColor: Colors.transparent,
                        height: 70,
                        elevation: 0,
                        labelTextStyle:
                            WidgetStateProperty.resolveWith((states) {
                          final isSelected =
                              states.contains(WidgetState.selected);
                          return theme.textTheme.bodySmall?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: 11,
                            color: isSelected
                                ? scheme.primary
                                : scheme.onSurface.withValues(alpha: 0.65),
                          );
                        }),
                        indicatorColor:
                            scheme.primary.withValues(alpha: 0.15),
                      ),
                      child: NavigationBar(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: _onDestinationSelected,
                        destinations: _items.map((item) {
                          Widget icon = Icon(item.icon);
                          Widget selectedIcon = Icon(item.selectedIcon);

                          if (item.isBeta) {
                            final badgeLabel = Text(
                              'BETA',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                                color: scheme.onPrimary,
                              ),
                            );
                            icon = Badge(
                              label: badgeLabel,
                              backgroundColor: scheme.primary,
                              offset: const Offset(14, -10),
                              child: icon,
                            );
                            selectedIcon = Badge(
                              label: badgeLabel,
                              backgroundColor: scheme.primary,
                              offset: const Offset(14, -10),
                              child: selectedIcon,
                            );
                          }

                          return NavigationDestination(
                            icon: icon,
                            selectedIcon: selectedIcon,
                            label: item.label,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Floating AI Bot Button ─────────────────────────────────────
        Positioned(
          right: 16,
          // 70 = nav bar height, + system bottom inset, + 8 margin
          bottom: MediaQuery.of(context).padding.bottom + 78,
          child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiChatScreen()),
                );
              },
              child: SizedBox(
                width: 70,
                height: 85,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primaryContainer,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      child: Hero(
                        tag: 'ai_bot_avatar',
                        child: Image.asset(
                          'assets/images/ai_bot.png',
                          height: 75,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const CircleAvatar(
                            child: Icon(Icons.auto_awesome),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
  final bool isBeta;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.screen,
    this.isBeta = false,
  });
}