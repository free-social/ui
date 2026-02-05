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
├── models/                   # All your data classes (Plain Dart Objects)
│   ├── user_model.dart       # User data structure
│   └── transaction_model.dart # Transaction data structure
│
├── services/                 # All API calls (Directly matching Postman)
│   ├── api_service.dart      # Setup Dio/Http client & Interceptors (Bearer token)
│   ├── auth_service.dart     # Calls /auth/login & /auth/register
│   └── expense_service.dart  # Calls /transactions (GET, POST, DELETE)
│
├── providers/                # State Management (Provider, Riverpod, or GetX controllers)
│   ├── auth_provider.dart    # Holds "User" state & Token
│   └── expense_provider.dart # Holds list of Transactions & monthly data
│
├── screens/                  # All your UI pages in one place
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── home_screen.dart      # Shows "get all transactions"
│   ├── add_expense_screen.dart
│   └── monthly_stats_screen.dart
│
├── widgets/                  # Reusable UI components
│   ├── custom_textfield.dart
│   └── transaction_tile.dart
│
└── main.dart
```