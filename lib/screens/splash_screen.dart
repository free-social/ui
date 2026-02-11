import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Needed for status bar
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

    // ✅ Transparent status bar without changing any colors
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // top is fully transparent
      statusBarIconBrightness: Brightness.light, // icons stay visible
    ));
  }

  Future<void> _initializeApp() async {
    final minDelay = Future.delayed(const Duration(seconds: 7));
    final authCheck = Provider.of<AuthProvider>(context, listen: false).checkAuthStatus();
    await Future.wait([minDelay, authCheck]);

    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.isAuthenticated) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color titleColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final Color subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[500]!;
    final Color progressBgColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;
    final Color footerColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;

    return Scaffold(
      extendBodyBehindAppBar: true, // ✅ Allows background to go behind status bar
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false, // ✅ No extra padding at top, background visible behind status bar
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // --- LOGO ---
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      kPrimaryColor,
                      kPrimaryColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryColor.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 24),

              // --- TITLE ---
              Text(
                "Spendwise",
                style: TextStyle(
                  fontFamily: "Poppins",
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // --- SUBTITLE ---
              Text(
                "Master your finances",
                style: TextStyle(
                  fontSize: 16,
                  color: subtitleColor,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),

              const Spacer(flex: 3),

              // --- LOADING INDICATOR ---
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: progressBgColor,
                    valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- FOOTER ---
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_outlined, size: 14, color: footerColor),
                  const SizedBox(width: 6),
                  Text(
                    "Secure v1.0.0",
                    style: TextStyle(fontSize: 12, color: footerColor, fontWeight: FontWeight.w500),
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
