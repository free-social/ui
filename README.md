# expenses

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# Folder Structure
```
lib/
├── main.dart                         # App entry point (MultiProvider, Theme setup, Routes)

├── models/                           # Pure data models (from API JSON)
│   ├── user_model.dart               # User structure
│   ├── transaction_model.dart        # Expense/Income structure
│   └── wallet_balance_model.dart     # Wallet balance response model

├── services/                         # API layer (HTTP communication only)
│   ├── api_service.dart              # Dio/HTTP setup + interceptors (Bearer token)
│   ├── auth_service.dart             # /auth (login, register, profile update)
│   ├── expense_service.dart          # /transactions (GET, POST, DELETE, UPDATE)
│   ├── wallet_service.dart           # /wallet (balance, topup, etc.)
│   └── notification_service.dart     # Local notifications logic

├── providers/                        # State management layer (business logic + state)
│   ├── auth_provider.dart            # Holds User + Token + login/logout logic
│   ├── expense_provider.dart         # Holds transaction list + monthly stats
│   ├── wallet_provider.dart          # Holds wallet balance state
│   └── theme_provider.dart           # Dark/Light theme switching

├── screens/                          # UI pages
│   ├── splash_screen.dart            # App startup logic (check token)
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── main_screen.dart              # BottomNavigation wrapper
│   ├── home_view.dart                # Transaction list dashboard
│   ├── transaction_form_screen.dart  # Add/Edit transaction
│   ├── monthly_stats_screen.dart     # Charts & analytics
│   ├── wallet_screen.dart            # Wallet overview
│   ├── user_profile.dart             # View profile
│   └── update_user_profile.dart      # Edit profile

├── widgets/                          # Reusable UI components
│   ├── custom_textfield.dart
│   └── transaction_tile.dart

└── utils/                            # Helpers & global configs
    ├── constants.dart                # API base URL, keys, app constants
    ├── snackbar_helper.dart          # Global snackbar function
    └── validation.dart               # Form validation helpers

```