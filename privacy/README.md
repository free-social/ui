## Privacy & Policy Summary
This section documents how the current app code handles user data.

### Data Collected
- Account data: username, email, password (for register/login requests).
- Authentication/session data: auth token and user ID.
- Profile data: username and avatar image.
- Finance data: transactions, categories, amounts, dates, wallet balance, and summary values.
- Support action: opening an email intent to contact support.

### How Data Is Used
- Authenticate users (email/password and Google login flow).
- Keep users signed in and attach auth token to API requests.
- Display and update profile information.
- Create, read, update, and delete transactions.
- Calculate and display daily/monthly stats and wallet views.

### Storage & Processing
- Local storage (device): `SharedPreferences` stores `token`, `userId`, and theme preference.
- Remote processing: app sends/receives data through backend API at:
  - `https://api-00fb.onrender.com/api/v1`
- Authorization header is attached automatically to protected API requests.
- On `401`, local auth/session data is cleared.

### Third-Party Services / Integrations
- Google OAuth flow via `flutter_web_auth_2` (`/auth/google` callback scheme: `spendwise`).
- Image upload support via `image_picker` + multipart upload.
- External link launching via `url_launcher` (support email).

### User Controls
- Users can logout (clears local session data).
- Users can update username and avatar.
- Users can create/edit/delete transactions and adjust wallet values.

### Security Notes
- Network access requires internet permission.
- Session token is persisted locally for login continuity.
- For production hardening, consider secure storage for auth tokens and legal review of this policy text.

## Testing Documentation
Total test files: `14`
Test categories:
- Models:
  - `test/models/transaction_model_test.dart`
  - `test/models/user_model_test.dart`
  - `test/models/wallet_balance_model_test.dart`
- Providers:
  - `test/providers/auth_provider_test.dart`
  - `test/providers/expense_provider_test.dart`
  - `test/providers/theme_provider_test.dart`
  - `test/providers/wallet_provider_test.dart`
- Services:
  - `test/services/api_service_test.dart`
  - `test/services/auth_service_test.dart`
  - `test/services/expense_service_test.dart`
  - `test/services/wallet_service_test.dart`
- Utils:
  - `test/utils/validation_test.dart`
- Widgets:
  - `test/widgets/transaction_tile_test.dart`
  - `test/widget_test.dart`

Last verification:
- Full scan date: `February 21, 2026`
- `flutter test`: all tests passed (`108`)
- `flutter analyze`: no issues found

<!-- TEST_CASE_TABLE_START -->
## Full Test Case Table (All 108 Cases)
Generated from runtime execution: `flutter test --machine`.

| # | Test File | Test Case | Type | Mocked | Result |
|---:|---|---|---|---|---|
| 1 | `test/models/transaction_model_test.dart` | TransactionModel fromJson should return a valid model from JSON | Unit | No | success |
| 2 | `test/models/transaction_model_test.dart` | TransactionModel fromJson should support MongoDB "_id" field | Unit | No | success |
| 3 | `test/models/transaction_model_test.dart` | TransactionModel toJson should return a JSON map (excluding ID) | Unit | No | success |
| 4 | `test/models/user_model_test.dart` | User Model fromJson creates a valid user from standard JSON | Unit | No | success |
| 5 | `test/models/user_model_test.dart` | User Model fromJson prioritizes MongoDB "_id" over standard "id" | Unit | No | success |
| 6 | `test/models/user_model_test.dart` | User Model fromJson falls back to "id" if "_id" is missing | Unit | No | success |
| 7 | `test/models/user_model_test.dart` | User Model fromJson handles missing or null fields safely | Unit | No | success |
| 8 | `test/models/user_model_test.dart` | User Model copyWith updates specific fields and keeps others | Unit | No | success |
| 9 | `test/models/user_model_test.dart` | User Model copyWith returns identical object if no arguments provided | Unit | No | success |
| 10 | `test/models/wallet_balance_model_test.dart` | WalletBalanceModel fromJson creates a valid wallet balance from standard JSON | Unit | No | success |
| 11 | `test/models/wallet_balance_model_test.dart` | WalletBalanceModel fromJson handles integer balance and converts to double | Unit | No | success |
| 12 | `test/models/wallet_balance_model_test.dart` | WalletBalanceModel fromJson handles missing fields with default values | Unit | No | success |
| 13 | `test/models/wallet_balance_model_test.dart` | WalletBalanceModel fromJson handles null balance field | Unit | No | success |
| 14 | `test/models/wallet_balance_model_test.dart` | WalletBalanceModel fromJson handles missing _id field | Unit | No | success |
| 15 | `test/models/wallet_balance_model_test.dart` | WalletBalanceModel fromJson handles missing user field | Unit | No | success |
| 16 | `test/models/wallet_balance_model_test.dart` | WalletBalanceModel constructor creates valid instance | Unit | No | success |
| 17 | `test/models/wallet_balance_model_test.dart` | WalletBalanceModel constructor handles zero balance | Unit | No | success |
| 18 | `test/models/wallet_balance_model_test.dart` | WalletBalanceModel constructor handles negative balance | Unit | No | success |
| 19 | `test/providers/auth_provider_test.dart` | AuthProvider checkAuthStatus finds token and logs user in automatically | Unit | Yes | success |
| 20 | `test/providers/auth_provider_test.dart` | AuthProvider checkAuthStatus stays logged out if no token exists | Unit | Yes | success |
| 21 | `test/providers/auth_provider_test.dart` | AuthProvider login calls service, fetches profile, and updates state | Unit | Yes | success |
| 22 | `test/providers/auth_provider_test.dart` | AuthProvider logout clears user and state | Unit | Yes | success |
| 23 | `test/providers/auth_provider_test.dart` | AuthProvider updateUsername updates the local user object | Unit | Yes | success |
| 24 | `test/providers/expense_provider_test.dart` | ExpenseProvider initial state should be empty | Unit | Yes | success |
| 25 | `test/providers/expense_provider_test.dart` | ExpenseProvider fetchTransactions populates the list (Page 1) | Unit | Yes | success |
| 26 | `test/providers/expense_provider_test.dart` | ExpenseProvider deleteTransaction removes item from list | Unit | Yes | success |
| 27 | `test/providers/expense_provider_test.dart` | ExpenseProvider addTransaction calls service and refreshes list | Unit | Yes | success |
| 28 | `test/providers/theme_provider_test.dart` | ThemeProvider initial state defaults to light mode when no saved preference | Unit | No | success |
| 29 | `test/providers/theme_provider_test.dart` | ThemeProvider loads saved light mode preference from SharedPreferences | Unit | No | success |
| 30 | `test/providers/theme_provider_test.dart` | ThemeProvider loads saved dark mode preference from SharedPreferences | Unit | No | success |
| 31 | `test/providers/wallet_provider_test.dart` | WalletProvider initial state is correct | Unit | Yes | success |
| 32 | `test/providers/wallet_provider_test.dart` | WalletProvider fetchWalletData sets loading state correctly | Unit | Yes | success |
| 33 | `test/providers/theme_provider_test.dart` | ThemeProvider toggleTheme changes from dark to light | Unit | No | success |
| 34 | `test/providers/wallet_provider_test.dart` | WalletProvider fetchWalletData success populates wallet data | Unit | Yes | success |
| 35 | `test/providers/wallet_provider_test.dart` | WalletProvider fetchWalletData handles errors correctly | Unit | Yes | success |
| 36 | `test/providers/wallet_provider_test.dart` | WalletProvider topUpWallet calls service and refreshes data | Unit | Yes | success |
| 37 | `test/providers/wallet_provider_test.dart` | WalletProvider topUpWallet handles errors and sets error state | Unit | Yes | success |
| 38 | `test/providers/wallet_provider_test.dart` | WalletProvider updateWalletBalance calls service and refreshes data | Unit | Yes | success |
| 39 | `test/providers/wallet_provider_test.dart` | WalletProvider updateWalletBalance handles errors and sets error state | Unit | Yes | success |
| 40 | `test/providers/wallet_provider_test.dart` | WalletProvider refreshData calls fetchWalletData | Unit | Yes | success |
| 41 | `test/providers/wallet_provider_test.dart` | WalletProvider clearError resets error to null | Unit | Yes | success |
| 42 | `test/providers/wallet_provider_test.dart` | WalletProvider notifyListeners is called on state changes | Unit | Yes | success |
| 43 | `test/providers/theme_provider_test.dart` | ThemeProvider toggleTheme changes from light to dark | Unit | No | success |
| 44 | `test/services/api_service_test.dart` | ApiService Interceptors Request should contain "Authorization" header when token exists | Unit | Yes | success |
| 45 | `test/services/api_service_test.dart` | ApiService Interceptors Request should NOT contain "Authorization" header when token is missing | Unit | Yes | success |
| 46 | `test/providers/theme_provider_test.dart` | ThemeProvider toggleTheme saves preference to SharedPreferences | Unit | No | success |
| 47 | `test/providers/theme_provider_test.dart` | ThemeProvider toggleTheme notifies listeners | Unit | No | success |
| 48 | `test/services/auth_service_test.dart` | AuthService login calls API and saves token/userId to SharedPreferences | Unit | Yes | success |
| 49 | `test/services/auth_service_test.dart` | AuthService register calls API with correct data | Unit | Yes | success |
| 50 | `test/services/auth_service_test.dart` | AuthService getProfile fetches user data | Unit | Yes | success |
| 51 | `test/services/auth_service_test.dart` | AuthService updateUsername sends PUT request | Unit | Yes | success |
| 52 | `test/services/auth_service_test.dart` | AuthService logout clears SharedPreferences | Unit | Yes | success |
| 53 | `test/providers/theme_provider_test.dart` | ThemeProvider multiple toggles work correctly | Unit | No | success |
| 54 | `test/services/expense_service_test.dart` | ExpenseService getAllTransactions handles standard list response | Unit | Yes | success |
| 55 | `test/services/expense_service_test.dart` | ExpenseService getAllTransactions handles Mongoose pagination ({docs: [...]}) | Unit | Yes | success |
| 56 | `test/services/expense_service_test.dart` | ExpenseService createTransaction posts data and returns model | Unit | Yes | success |
| 57 | `test/services/expense_service_test.dart` | ExpenseService deleteTransaction sends delete request | Unit | Yes | success |
| 58 | `test/services/expense_service_test.dart` | ExpenseService Throws exception when API fails | Unit | Yes | success |
| 59 | `test/services/wallet_service_test.dart` | WalletService fetchWalletData throws when userId is not found | Unit | Yes | success |
| 60 | `test/services/wallet_service_test.dart` | WalletService topUpWallet sends PATCH request with correct data | Unit | Yes | success |
| 61 | `test/services/wallet_service_test.dart` | WalletService topUpWallet handles errors correctly | Unit | Yes | success |
| 62 | `test/services/wallet_service_test.dart` | WalletService updateWalletBalance sends PUT request with correct data | Unit | Yes | success |
| 63 | `test/services/wallet_service_test.dart` | WalletService updateWalletBalance handles errors correctly | Unit | Yes | success |
| 64 | `test/services/wallet_service_test.dart` | WalletService previous month calculation handles January correctly | Unit | Yes | success |
| 65 | `test/services/wallet_service_test.dart` | WalletService previous month calculation handles other months correctly | Unit | Yes | success |
| 66 | `test/utils/validation_test.dart` | ValidationUtils isValidPassword returns true for valid password | Unit | No | success |
| 67 | `test/utils/validation_test.dart` | ValidationUtils isValidPassword returns false if too short | Unit | No | success |
| 68 | `test/utils/validation_test.dart` | ValidationUtils isValidPassword returns false if missing uppercase | Unit | No | success |
| 69 | `test/utils/validation_test.dart` | ValidationUtils isValidPassword returns false if missing lowercase | Unit | No | success |
| 70 | `test/utils/validation_test.dart` | ValidationUtils isValidPassword returns false if missing digit | Unit | No | success |
| 71 | `test/utils/validation_test.dart` | ValidationUtils isValidPassword returns false if missing special character | Unit | No | success |
| 72 | `test/utils/validation_test.dart` | ValidationUtils isValidEmail returns true for valid email | Unit | No | success |
| 73 | `test/utils/validation_test.dart` | ValidationUtils isValidEmail returns false for plain text | Unit | No | success |
| 74 | `test/utils/validation_test.dart` | ValidationUtils isValidEmail returns false for missing domain | Unit | No | success |
| 75 | `test/utils/validation_test.dart` | ValidationUtils isValidEmail returns false for missing extension | Unit | No | success |
| 76 | `test/utils/validation_test.dart` | ValidationUtils isValidUsername returns true for 3 or more chars | Unit | No | success |
| 77 | `test/utils/validation_test.dart` | ValidationUtils isValidUsername returns false for less than 3 chars | Unit | No | success |
| 78 | `test/utils/validation_test.dart` | ValidationUtils validatePassword returns error when null | Unit | No | success |
| 79 | `test/utils/validation_test.dart` | ValidationUtils validatePassword returns error when empty | Unit | No | success |
| 80 | `test/utils/validation_test.dart` | ValidationUtils validatePassword returns error when too short | Unit | No | success |
| 81 | `test/utils/validation_test.dart` | ValidationUtils validatePassword returns error when missing lowercase | Unit | No | success |
| 82 | `test/utils/validation_test.dart` | ValidationUtils validatePassword returns error when missing uppercase | Unit | No | success |
| 83 | `test/utils/validation_test.dart` | ValidationUtils validatePassword returns error when missing number | Unit | No | success |
| 84 | `test/utils/validation_test.dart` | ValidationUtils validatePassword returns error when missing special char | Unit | No | success |
| 85 | `test/utils/validation_test.dart` | ValidationUtils validatePassword returns null when valid | Unit | No | success |
| 86 | `test/utils/validation_test.dart` | ValidationUtils validateEmail returns error when null | Unit | No | success |
| 87 | `test/utils/validation_test.dart` | ValidationUtils validateEmail returns error when empty | Unit | No | success |
| 88 | `test/utils/validation_test.dart` | ValidationUtils validateEmail returns error when invalid format | Unit | No | success |
| 89 | `test/utils/validation_test.dart` | ValidationUtils validateEmail returns null when valid | Unit | No | success |
| 90 | `test/utils/validation_test.dart` | ValidationUtils validateUsername returns error when null | Unit | No | success |
| 91 | `test/utils/validation_test.dart` | ValidationUtils validateUsername returns error when empty | Unit | No | success |
| 92 | `test/utils/validation_test.dart` | ValidationUtils validateUsername returns error when too short | Unit | No | success |
| 93 | `test/utils/validation_test.dart` | ValidationUtils validateUsername returns null when valid | Unit | No | success |
| 94 | `test/widgets/transaction_tile_test.dart` | TransactionTile Widget renders transaction data correctly | Widget | Yes | success |
| 95 | `test/widget_test.dart` | App loads login screen | Widget | No | success |
| 96 | `test/widgets/transaction_tile_test.dart` | TransactionTile Widget shows correct category initial in CircleAvatar | Widget | Yes | success |
| 97 | `test/widgets/transaction_tile_test.dart` | TransactionTile Widget handles empty category gracefully | Widget | Yes | success |
| 98 | `test/widgets/transaction_tile_test.dart` | TransactionTile Widget formats amount with 2 decimal places | Widget | Yes | success |
| 99 | `test/widgets/transaction_tile_test.dart` | TransactionTile Widget shows edit and delete buttons | Widget | Yes | success |
| 100 | `test/widgets/transaction_tile_test.dart` | TransactionTile Widget delete button shows confirmation dialog | Widget | Yes | success |
| 101 | `test/widgets/transaction_tile_test.dart` | TransactionTile Widget delete confirmation dialog Cancel button dismisses dialog | Widget | Yes | success |
| 102 | `test/widgets/transaction_tile_test.dart` | TransactionTile Widget delete confirmation dialog Delete button calls provider | Widget | Yes | success |
| 103 | `test/widgets/transaction_tile_test.dart` | TransactionTile Widget swipe-to-delete shows delete background | Widget | Yes | success |
| 104 | `test/widgets/transaction_tile_test.dart` | TransactionTile Widget tap on tile opens edit screen | Widget | Yes | success |
| 105 | `test/widgets/transaction_tile_test.dart` | TransactionTile Widget edit button opens edit screen | Widget | Yes | success |
| 106 | `test/widgets/transaction_tile_test.dart` | TransactionTile Widget capitalizes category name correctly | Widget | Yes | success |
| 107 | `test/widgets/transaction_tile_test.dart` | TransactionTile Widget Dismissible has correct key | Widget | Yes | success |
| 108 | `test/widgets/transaction_tile_test.dart` | TransactionTile Widget displays Card with proper styling | Widget | Yes | success |
<!-- TEST_CASE_TABLE_END -->

## Quality Process Used
- Static code analysis with `flutter analyze`
- Automated test run with `flutter test`
- Validation of architecture boundaries (UI/state/service/model separation)
- Documentation alignment with implemented features and tests

## Configuration
API base URL is set in `lib/utils/constants.dart`:
- `https://api-00fb.onrender.com/api/v1`

Demo credentials are in `DEMO_CREDENTIALS.md`.

## Run Locally
1. Install dependencies:
```bash
flutter pub get
```
2. Run app:
```bash
flutter run
```
3. Analyze:
```bash
flutter analyze
```
4. Run tests:
```bash
flutter test
```



