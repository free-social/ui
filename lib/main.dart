import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/navigation/app_navigator.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/sport_provider.dart';
import 'screens/chat_call_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/splash_screen.dart';
import 'services/callkit_service.dart';
import 'services/push_notification_service.dart';
import 'core/widgets/network_aware_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.instance.initialize();
  await CallKitService.instance.initialize();

  // Initialize AuthProvider
  final authProvider = AuthProvider();
  await authProvider.checkAuthStatus();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, auth, chatProvider) {
            final provider = chatProvider ?? ChatProvider();
            unawaited(provider.syncAuthState(auth.isAuthenticated));
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SportProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

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
          routes: {
            '/chat-call': (_) => const ChatCallScreen(),
            '/login': (_) => const LoginScreen(),
            '/main': (_) => const MainScreen(),
            '/splash': (_) => const SplashScreen(),
          },
          builder: (context, child) {
            return NetworkAwareWidget(
              child: child ?? const SizedBox.shrink(),
            );
          },
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
