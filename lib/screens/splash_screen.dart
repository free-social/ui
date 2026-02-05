import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final Color kPrimaryColor = const Color(0xFF00C897);

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Minimum delay
    final minDelay = Future.delayed(const Duration(seconds: 7));

    // 2. Auth Check
    final authCheck = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).checkAuthStatus();

    // 3. Wait for BOTH
    await Future.wait([minDelay, authCheck]);

    // 4. Navigate
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.isAuthenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ SETUP DYNAMIC COLORS
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ✅ FIX: Force non-nullable 'Color' types for safety
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final Color subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[500]!;
    final Color progressBgColor = isDark
        ? Colors.grey[800]!
        : Colors.grey[100]!;
    final Color footerColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;

    return Scaffold(
      // Background uses Theme's scaffoldBackgroundColor automatically
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // --- 1. LOGO SECTION ---
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      kPrimaryColor,
                      kPrimaryColor.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),

              // --- 2. TITLE TEXT ---
              Text(
                "Spendwise",
                style: TextStyle(
                  fontFamily: "Poppins",
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: titleColor, // ✅ Dynamic
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // --- 3. SUBTITLE TEXT ---
              Text(
                "Master your finances",
                style: TextStyle(
                  fontSize: 16,
                  color: subtitleColor, // ✅ Dynamic
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),

              const Spacer(flex: 3),

              // --- 4. LOADING INDICATOR ---
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: progressBgColor, // ✅ Dynamic
                    valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- 5. FOOTER (Secure v1.0.0) ---
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 14,
                    color: footerColor, // ✅ Dynamic
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Secure v1.0.0",
                    style: TextStyle(
                      fontSize: 12,
                      color: footerColor, // ✅ Dynamic
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
