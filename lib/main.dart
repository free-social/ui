import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Notifications
  try {
    await NotificationService.initialize();
    await NotificationService.requestPermissions();
    await NotificationService.scheduleDailyNotification();

    // Check if we should show notification (fallback for OPPO)
    await NotificationService.checkAndShowIfNeeded();
  } catch (e) {
    // Ignore notification errors - app should still work without notifications
    print('⚠️ Notification setup failed: $e');
  }

  // Initialize AuthProvider
  final authProvider = AuthProvider();
  await authProvider.checkAuthStatus();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Spendwise',
          debugShowCheckedModeBanner: false,

          // Light Theme
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF2F4F7),
            primaryColor: const Color(0xFF00BFA5),
            cardColor: Colors.white,
            dividerColor: Colors.grey.shade200,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF2F4F7),
              iconTheme: IconThemeData(color: Colors.black),
              titleTextStyle: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.black87),
              bodyMedium: TextStyle(color: Colors.black87),
            ),
            snackBarTheme: const SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              elevation: 8,
            ),
          ),

          // Dark Theme
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            primaryColor: const Color(0xFF00BFA5),
            cardColor: const Color(0xFF1E1E1E),
            dividerColor: Colors.grey.shade800,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white),
            ),
            snackBarTheme: const SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              elevation: 8,
            ),
          ),

          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}


// Test 