# Spendwise - Expense Tracking Application

## Project Overview

**Spendwise** is a comprehensive Flutter-based mobile expense tracking application that helps users manage their finances effectively. The app provides features for tracking transactions, viewing spending statistics, managing a digital wallet, and customizing user profiles.

### Key Features

- User authentication (Email/Password and Google OAuth)
- Transaction management (Create, Read, Update, Delete)
- Category-based expense tracking
- Monthly and daily spending statistics
- Digital wallet with balance management
- Dark/Light theme support
- User profile management with avatar upload
- Pull-to-refresh and infinite scroll
- Responsive UI with Material Design

### Technology Stack

- **Framework**: Flutter 3.10.3+
- **State Management**: Provider
- **HTTP Client**: Dio 5.4.0
- **Local Storage**: SharedPreferences
- **Date Formatting**: Intl
- **Image Picking**: Image Picker
- **Authentication**: Flutter Web Auth 2
- **Testing**: Mockito, Flutter Test

---

## Project Structure

```
lib/
├── main.dart                      # Application entry point
├── models/                        # Data models
│   ├── user_model.dart           # User data structure
│   ├── transaction_model.dart    # Transaction data structure
│   └── wallet_balance_model.dart # Wallet balance structure
├── services/                      # API integration layer
│   ├── api_service.dart          # Dio HTTP client setup
│   ├── auth_service.dart         # Authentication API calls
│   ├── expense_service.dart      # Transaction API calls
│   └── wallet_service.dart       # Wallet API calls
├── providers/                     # State management
│   ├── auth_provider.dart        # Authentication state
│   ├── expense_provider.dart     # Transaction state
│   └── theme_provider.dart       # Theme state
├── screens/                       # UI screens
│   ├── splash_screen.dart        # Initial loading screen
│   ├── login_screen.dart         # Login page
│   ├── register_screen.dart      # Registration page
│   ├── main_screen.dart          # Bottom navigation container
│   ├── home_view.dart            # Transaction list view
│   ├── transaction_form_screen.dart # Add/Edit transaction
│   ├── monthly_stats_screen.dart # Statistics view
│   ├── wallet_screen.dart        # Wallet management
│   ├── user_profile.dart         # User settings
│   └── update_user_profile.dart  # Profile editor
├── widgets/                       # Reusable components
│   ├── custom_textfield.dart     # Custom input field
│   └── transaction_tile.dart     # Transaction list item
└── utils/                         # Utilities
    ├── constants.dart            # API endpoints
    └── validation.dart           # Form validation
```

---

## Architecture

### Design Pattern

The application follows the **Provider Pattern** for state management with a clear separation of concerns:

1. **Models**: Plain Dart objects representing data structures
2. **Services**: API communication layer using Dio
3. **Providers**: State management using ChangeNotifier
4. **Screens**: UI components consuming provider state
5. **Widgets**: Reusable UI components

### Data Flow

```
User Action → Screen → Provider → Service → API
                ↓         ↓
            UI Update ← State Change
```

---

## Core Components

### 1. Models

#### User Model (`lib/models/user_model.dart`)

Represents user account information.

**Properties:**

- `id`: String - Unique user identifier (MongoDB \_id)
- `email`: String - User email address
- `username`: String - Display name
- `avatar`: String - Profile picture URL

**Methods:**

- `fromJson()`: Factory constructor for API response parsing
- `copyWith()`: Creates a copy with updated fields

#### Transaction Model (`lib/models/transaction_model.dart`)

Represents a financial transaction.

**Properties:**

- `id`: String - Unique transaction identifier
- `amount`: double - Transaction amount (positive for income, negative for expense)
- `category`: String - Transaction category (food, travel, bills, etc.)
- `description`: String - Transaction note/description
- `date`: DateTime - Transaction date

**Methods:**

- `fromJson()`: Parses API response (handles both 'date' and 'createdAt' fields)
- `toJson()`: Converts to JSON for API requests

#### Wallet Balance Model (`lib/models/wallet_balance_model.dart`)

Represents user's wallet balance.

**Properties:**

- `id`: String - Wallet identifier
- `balance`: double - Current wallet balance
- `userId`: String - Associated user ID

---

### 2. Services

#### API Service (`lib/services/api_service.dart`)

Base HTTP client configuration using Dio.

**Features:**

- Base URL configuration from constants
- JWT token interceptor (automatically adds Bearer token to requests)
- Request/response logging
- Error handling

**Configuration:**

```dart
BaseOptions(baseUrl: ApiConstants.baseUrl)
```

**Interceptor:**

- Reads token from SharedPreferences
- Adds Authorization header to all requests
- Logs request URLs and errors

#### Auth Service (`lib/services/auth_service.dart`)

Handles all authentication-related API calls.

**API Endpoints:**

- `POST /auth/register` - User registration
- `POST /auth/login` - Email/password login
- `GET /auth/google` - Google OAuth authentication
- `GET /auth/:id/profile` - Fetch user profile
- `PUT /auth/:id` - Update username
- `POST /auth/:id/avatar` - Upload profile picture

**Key Methods:**

- `register(username, email, password)`: Creates new user account
- `login(email, password)`: Authenticates user and stores token + userId
- `googleAuth()`: Initiates Google OAuth flow using FlutterWebAuth2
- `getProfile(userId)`: Fetches current user data from database
- `updateUsername(userId, newUsername)`: Updates user's display name
- `uploadAvatar(userId, imageFile)`: Uploads profile picture (multipart/form-data)
- `logout()`: Clears local storage

**Token Management:**

- Stores JWT token in SharedPreferences
- Stores userId for profile fetching
- Automatically includes token in subsequent requests via interceptor

#### Expense Service (`lib/services/expense_service.dart`)

Manages transaction-related API operations.

**API Endpoints:**

- `GET /transactions` - Get all transactions (with pagination & filters)
- `GET /transactions/monthly` - Get monthly summary
- `GET /transactions/daily` - Get daily summary
- `GET /transactions/:id` - Get single transaction
- `POST /transactions` - Create new transaction
- `PUT /transactions/:id` - Update transaction
- `DELETE /transactions/:id` - Delete transaction

**Key Methods:**

- `getAllTransactions({page, limit, category, sortBy, sortOrder})`: Fetches paginated transaction list
- `getMonthlyExpenses(month, year)`: Returns monthly spending data
- `getDailyExpenses({date})`: Returns daily spending data
- `getMonthlyExpenseTotal(month, year)`: Calculates total expenses for a month
- `createTransaction(transaction)`: Creates new transaction
- `updateTransaction(id, updates)`: Updates existing transaction
- `deleteTransaction(id)`: Removes transaction

**Pagination Support:**

- Handles both Mongoose pagination structure (`docs` field) and plain arrays
- Supports filtering by category
- Supports sorting by date/amount

#### Wallet Service (`lib/services/wallet_service.dart`)

Manages wallet balance and aggregated data.

**API Endpoints:**

- `GET /wallet` - Get wallet balance
- `PATCH /wallet/adjust` - Adjust wallet balance

**Key Methods:**

- `fetchWalletData()`: Fetches user profile, recent transactions, wallet balance, and last month's expenses in parallel
- `topUpWallet(amount)`: Adds or subtracts from wallet balance

**Returns:**

- `WalletData` object containing user, transactions, wallet balance, and previous month expense

---

### 3. Providers (State Management)

#### Auth Provider (`lib/providers/auth_provider.dart`)

Manages authentication state and user session.

**State Variables:**

- `_user`: User? - Current logged-in user
- `_isAuthenticated`: bool - Authentication status
- `_isLoading`: bool - Loading indicator

**Key Methods:**

- `checkAuthStatus()`: Checks if user is logged in on app start (reads token from SharedPreferences)
- `login(email, password)`: Authenticates user and fetches profile
- `register(username, email, password)`: Creates new account
- `googleLogin()`: Handles Google OAuth flow
- `updateUsername(userId, newUsername)`: Updates username and refreshes state
- `uploadAvatar(userId, imageFile)`: Uploads avatar and updates state
- `logout()`: Clears session and resets state

**Features:**

- Persists authentication across app restarts
- Automatically fetches user profile after login
- Updates UI reactively via `notifyListeners()`

#### Expense Provider (`lib/providers/expense_provider.dart`)

Manages transaction list and statistics.

**State Variables:**

- `_transactions`: List<TransactionModel> - Transaction list
- `_isLoading`: bool - Loading state
- `_monthlySummary`: dynamic - Monthly statistics
- `_dailySummary`: dynamic - Daily statistics
- `_currentPage`: int - Current pagination page
- `_currentCategory`: String? - Active filter
- `_currentSortBy`: String - Sort field (default: 'date')
- `_currentSortOrder`: String - Sort direction (default: 'desc')

**Key Methods:**

- `fetchTransactions({page, limit, category, sortBy, sortOrder, forceRefresh})`: Loads transactions with pagination
- `addTransaction(amount, category, desc, date)`: Creates new transaction
- `updateTransaction(id, updates)`: Updates existing transaction
- `deleteTransaction(id)`: Removes transaction
- `fetchMonthlyExpenses(month, year)`: Loads monthly summary
- `fetchDailyExpenses([date])`: Loads daily summary
- `clearFilters()`: Resets all filters

**Pagination Logic:**

- Page 1: Replaces entire list (new filter or refresh)
- Page 2+: Appends to existing list (load more)

#### Theme Provider (`lib/providers/theme_provider.dart`)

Manages app theme (light/dark mode).

**State Variables:**

- `_themeMode`: ThemeMode - Current theme (light/dark)

**Key Methods:**

- `toggleTheme(isDark)`: Switches theme and persists to SharedPreferences
- `_loadTheme()`: Loads saved theme preference on app start

**Features:**

- Persists theme preference across app restarts
- Defaults to dark mode

---

### 4. Screens (UI)

#### Splash Screen (`lib/screens/splash_screen.dart`)

Initial loading screen displayed on app launch.

**Features:**

- Displays app logo and branding
- Shows loading indicator
- Checks authentication status
- Navigates to Login or Main screen based on auth state
- Minimum 7-second display duration
- Adapts to light/dark theme

**Navigation Logic:**

```dart
if (isAuthenticated) → MainScreen
else → LoginScreen
```

#### Login Screen (`lib/screens/login_screen.dart`)

User authentication interface.

**Features:**

- Email and password input fields
- Password visibility toggle
- Form validation
- Manual login button
- Google OAuth login button
- Link to registration screen
- Loading state during authentication
- Theme-adaptive UI

**Form Fields:**

- Email (with email icon)
- Password (with lock icon and visibility toggle)

**Actions:**

- Sign In: Validates and calls `authProvider.login()`
- Sign in with Google: Calls `authProvider.googleLogin()`
- Sign Up link: Navigates to RegisterScreen

#### Register Screen (`lib/screens/register_screen.dart`)

New user registration interface.

**Features:**

- Full name, email, and password input
- Real-time form validation
- Password strength requirements
- Loading state during registration
- Link back to login screen
- Theme-adaptive UI

**Validation Rules:**

- Username: Minimum 3 characters
- Email: Valid email format
- Password: Minimum 6 characters, must contain uppercase, lowercase, number, and special character

**Actions:**

- Sign Up: Validates and calls `authProvider.register()`
- Success: Navigates back to login with success message

#### Main Screen (`lib/screens/main_screen.dart`)

Bottom navigation container with 4 tabs.

**Navigation Structure:**

- Tab 0: Home (Transaction List)
- Tab 1: Stats (Monthly Statistics)
- Tab 2: Wallet (Wallet Management)
- Tab 3: Profile (User Settings)

**Features:**

- PageView for smooth tab transitions
- Floating Action Button (FAB) for adding transactions
- Bottom navigation bar with notched design
- Active tab highlighting
- Theme-adaptive colors

#### Home View (`lib/screens/home_view.dart`)

Main transaction list screen.

**Features:**

- User profile header with avatar
- Current date display
- Total balance calculation
- Category filter chips (All, Food, Travel, Shopping, Bills, Other)
- Infinite scroll pagination
- Pull-to-refresh
- Transaction cards with category icons
- Tap to edit transaction
- Theme-adaptive UI

**Header Section:**

- Welcome message with username
- User avatar (from profile or default)
- Current date in "EEEE, MMM d" format
- Total amount display (sum of filtered transactions)
- Notification icon

**Filter Bar:**

- Horizontal scrollable chip list
- Active filter highlighted in primary color
- Filters transactions by category

**Transaction List:**

- Displays recent transactions
- Shows category icon, description, date, and amount
- Color-coded by category
- Infinite scroll (loads more on scroll to bottom)
- Pull-to-refresh support
- Empty state handling

**Category Icons & Colors:**

- Food: Coffee icon, Teal
- Travel: Car icon, Orange
- Shopping: Shopping bag icon, Purple
- Bills: Receipt icon, Red
- Rent: Home icon, Indigo
- Other: Category icon, Blue Grey

#### Transaction Form Screen (`lib/screens/transaction_form_screen.dart`)

Add/Edit transaction interface.

**Features:**

- Large amount input with currency prefix
- Date picker
- Category selector (horizontal scrollable)
- Note/description input
- Save/Update button
- Delete button (edit mode only)
- Loading states
- Theme-adaptive UI

**Form Fields:**

- Amount: Numeric keyboard, centered display with $ prefix
- Date: Date picker dialog (limited to past dates)
- Category: Visual icon-based selector
- Note: Text input with notes icon

**Validation:**

- Amount must be greater than 0
- Category must be selected
- Description is optional

**Actions:**

- Save Expense: Creates new transaction
- Update Expense: Updates existing transaction
- Delete: Shows confirmation dialog before deletion

#### Monthly Stats Screen (`lib/screens/monthly_stats_screen.dart`)

Spending statistics and analytics.

**Features:**

- Toggle between Daily and Monthly views
- Date navigation (month selector for monthly view)
- Circular progress ring showing category breakdown
- Total spent display
- Category list with progress bars
- Percentage calculations
- Pull-to-refresh
- Theme-adaptive UI

**Toggle Views:**

- Daily: Shows spending for selected day
- Monthly: Shows spending for selected month with navigation arrows

**Circular Ring Chart:**

- Custom painted multi-segment ring
- Each segment represents a category
- Color-coded by category
- Displays total spent in center

**Category List:**

- Shows each category with icon
- Displays amount and percentage
- Linear progress bar
- Sorted by amount (highest first)
- Empty state when no data

**Custom Painter:**

- `MultiSegmentPainter`: Draws circular chart with multiple colored segments

#### Wallet Screen (`lib/screens/wallet_screen.dart`)

Digital wallet management interface.

**Features:**

- Three swipeable cards showing:
  1. Transaction Net (sum of recent transactions)
  2. Total Wallet Balance (from wallet API)
  3. Last Month Expense
- Action buttons: Top Up, Pay, Scan, More
- Recent transactions list
- Pull-to-refresh
- Theme-adaptive UI

**Wallet Cards:**

- Gradient backgrounds
- Large amount display
- Icon indicators
- Swipeable PageView

**Action Buttons:**

- Top Up: Opens dialog to add funds to wallet
- Pay: Opens dialog to deduct funds (with balance check)
- Scan: Placeholder for QR code scanning
- More: Placeholder for additional features

**Top Up Flow:**

1. User enters amount
2. Wallet balance is adjusted via API
3. Transaction is created with "Top Up" category
4. UI refreshes to show new balance

**Pay Flow:**

1. User enters expense amount
2. Checks if balance is sufficient
3. If insufficient, shows warning dialog
4. If sufficient, deducts from wallet and creates expense transaction
5. UI refreshes

**Transaction List:**

- Shows recent transactions
- Income displayed in green with "+" prefix
- Expenses displayed in black
- Category icons and colors
- Date and time formatting

#### User Profile Screen (`lib/screens/user_profile.dart`)

User settings and preferences.

**Features:**

- Profile header with avatar and user info
- Tap to edit profile
- Preferences section (Notifications, Dark Mode)
- Account section (Currency, Security)
- Support section (Help & Support)
- Logout button
- Version display
- Theme-adaptive UI

**Profile Header:**

- Large circular avatar with edit badge
- Username and email display
- Tap to navigate to edit screen

**Settings Sections:**

1. **Preferences:**
   - Enable Notifications: Toggle switch
   - Dark Mode: Toggle switch (connected to ThemeProvider)

2. **Account:**
   - Currency: Shows "USD" (static)
   - Security: Navigation to security settings (placeholder)

3. **Support:**
   - Help & Support: Opens email client (mailto:oeunnuphea@gmail.com)

**Logout:**

- Clears authentication state
- Navigates to login screen
- Removes all navigation history

#### Update User Profile Screen (`lib/screens/update_user_profile.dart`)

Profile editing interface.

**Features:**

- Avatar preview with camera button
- Image picker integration
- Username input field
- Save button with loading state
- Theme-adaptive UI

**Avatar Management:**

- Displays current avatar or default
- Shows selected image preview
- Camera button overlay
- Opens gallery picker on tap

**Form Fields:**

- Full Name: Text input with validation

**Actions:**

- Change Profile Photo: Opens image picker
- Save Changes: Updates username and/or avatar
  - Only sends API requests for changed fields
  - Shows success message on completion
  - Navigates back to profile screen

**Image Upload:**

- Uses ImagePicker to select from gallery
- Converts to File object
- Uploads via multipart/form-data
- Updates avatar URL in state

---

### 5. Utilities

#### Constants (`lib/utils/constants.dart`)

Centralized configuration values.

**API Configuration:**

```dart
class ApiConstants {
  static const String baseUrl = 'https://api-00fb.onrender.com/api/v1';
}
```

**Usage:**

- Used by ApiService to configure Dio base URL
- Easy to switch between development, staging, and production environments

**Environment Options (commented):**

- Local development: `http://localhost:4001/api/v1`
- Production: `https://api-00fb.onrender.com/api/v1`

#### Validation (`lib/utils/validation.dart`)

Form validation utilities.

**Validation Methods:**

1. **validatePassword(password)**
   - Required field check
   - Minimum 6 characters
   - Must contain lowercase letter
   - Must contain uppercase letter
   - Must contain number
   - Must contain special character (!@#$%^&\*)

2. **validateEmail(email)**
   - Required field check
   - Valid email format (regex: `^[^@]+@[^@]+\.[^@]+$`)

3. **validateUsername(username)**
   - Required field check
   - Minimum 3 characters

**Helper Methods:**

- `isValidPassword(password)`: Returns boolean
- `isValidEmail(email)`: Returns boolean
- `isValidUsername(username)`: Returns boolean

**Usage:**

```dart
TextFormField(
  validator: ValidationUtils.validateEmail,
)
```

---

## Application Flow

### 1. App Initialization

```
main()
  → WidgetsFlutterBinding.ensureInitialized()
  → AuthProvider.checkAuthStatus() (checks token in SharedPreferences)
  → MultiProvider setup
  → MyApp widget
```

### 2. Authentication Flow

**First Time User:**

```
SplashScreen → LoginScreen → RegisterScreen → LoginScreen → MainScreen
```

**Returning User:**

```
SplashScreen → (auto-login) → MainScreen
```

**Google OAuth:**

```
LoginScreen → Google OAuth Web View → Callback with token → MainScreen
```

### 3. Transaction Management Flow

**Create Transaction:**

```
MainScreen (FAB) → TransactionFormScreen → Enter Details → Save
  → ExpenseProvider.addTransaction()
  → ExpenseService.createTransaction()
  → API POST /transactions
  → Refresh transaction list
  → Navigate back to HomeView
```

**Edit Transaction:**

```
HomeView → Tap Transaction Card → TransactionFormScreen (with data)
  → Modify Details → Update
  → ExpenseProvider.updateTransaction()
  → ExpenseService.updateTransaction()
  → API PUT /transactions/:id
  → Refresh transaction list
  → Navigate back
```

**Delete Transaction:**

```
TransactionFormScreen → Delete Button → Confirmation Dialog → Confirm
  → ExpenseProvider.deleteTransaction()
  → ExpenseService.deleteTransaction()
  → API DELETE /transactions/:id
  → Remove from local list
  → Navigate back
```

### 4. Wallet Management Flow

**Top Up:**

```
WalletScreen → Top Up Button → Enter Amount → Confirm
  → WalletService.topUpWallet(+amount)
  → API PATCH /wallet/adjust
  → Create "Top Up" transaction
  → Refresh wallet data
```

**Pay (Expense):**

```
WalletScreen → Pay Button → Enter Amount → Confirm
  → Check balance sufficiency
  → If insufficient: Show warning
  → If sufficient:
    → WalletService.topUpWallet(-amount)
    → Create "Expense" transaction
    → Refresh wallet data
```

### 5. Profile Update Flow

**Update Username:**

```
UserProfileScreen → Tap Avatar → UpdateUserProfile
  → Edit Name → Save
  → AuthProvider.updateUsername()
  → AuthService.updateUsername()
  → API PUT /auth/:id
  → Update local user state
  → Navigate back
```

**Update Avatar:**

```
UpdateUserProfile → Camera Button → Select Image
  → Preview selected image
  → Save
  → AuthProvider.uploadAvatar()
  → AuthService.uploadAvatar()
  → API POST /auth/:id/avatar (multipart)
  → Update local user state with new avatar URL
  → Navigate back
```

---

## State Management Details

### Provider Pattern Implementation

**Provider Setup (main.dart):**

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => ExpenseProvider()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
  ],
  child: MyApp(),
)
```

**Consuming State:**

```dart
// Read-only access (no rebuilds)
final authProvider = Provider.of<AuthProvider>(context, listen: false);

// Reactive access (rebuilds on state change)
final authProvider = Provider.of<AuthProvider>(context);

// Using Consumer widget
Consumer<ExpenseProvider>(
  builder: (context, provider, child) {
    return ListView.builder(
      itemCount: provider.transactions.length,
      itemBuilder: (context, index) => TransactionCard(provider.transactions[index]),
    );
  },
)
```

**State Updates:**

```dart
// In Provider class
void updateState() {
  _someValue = newValue;
  notifyListeners(); // Triggers rebuild of listening widgets
}
```

---

## API Integration

### Base URL Configuration

```dart
// Production
https://api-00fb.onrender.com/api/v1

// Local Development
http://localhost:4001/api/v1
```

### Authentication Headers

All authenticated requests automatically include:

```
Authorization: Bearer <jwt_token>
```

### API Endpoints Summary

**Authentication:**

- `POST /auth/register` - Create account
- `POST /auth/login` - Login with email/password
- `GET /auth/google` - Google OAuth
- `GET /auth/:id/profile` - Get user profile
- `PUT /auth/:id` - Update username
- `POST /auth/:id/avatar` - Upload avatar

**Transactions:**

- `GET /transactions?page=1&limit=10&category=food&sortBy=date&sortOrder=desc` - List transactions
- `GET /transactions/monthly?month=1&year=2024` - Monthly summary
- `GET /transactions/daily?date=2024-01-15` - Daily summary
- `GET /transactions/:id` - Get single transaction
- `POST /transactions` - Create transaction
- `PUT /transactions/:id` - Update transaction
- `DELETE /transactions/:id` - Delete transaction

**Wallet:**

- `GET /wallet` - Get wallet balance
- `PATCH /wallet/adjust` - Adjust balance

### Request/Response Examples

**Login Request:**

```json
POST /auth/login
{
  "email": "user@example.com",
  "password": "Password123!"
}
```

**Login Response:**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "507f1f77bcf86cd799439011",
    "email": "user@example.com",
    "username": "John Doe",
    "avatar": "https://example.com/avatar.jpg"
  }
}
```

**Create Transaction Request:**

```json
POST /transactions
{
  "amount": -50.00,
  "category": "food",
  "description": "Lunch at restaurant",
  "date": "2024-01-15T12:30:00.000Z"
}
```

**Transaction Response:**

```json
{
  "_id": "507f1f77bcf86cd799439011",
  "amount": -50.0,
  "category": "food",
  "description": "Lunch at restaurant",
  "date": "2024-01-15T12:30:00.000Z",
  "createdAt": "2024-01-15T12:30:00.000Z"
}
```

---

## Theme System

### Theme Configuration

**Light Theme:**

- Background: `#F2F4F7` (Light grey)
- Card: White
- Primary: `#00BFA5` (Teal)
- Text: Black/Dark grey
- Divider: Light grey

**Dark Theme:**

- Background: `#121212` (Dark grey)
- Card: `#1E1E1E` (Slightly lighter dark)
- Primary: `#00BFA5` (Teal - same as light)
- Text: White/Light grey
- Divider: Dark grey

**Theme Definition (main.dart):**

```dart
ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: Color(0xFFF2F4F7),
  primaryColor: Color(0xFF00BFA5),
  cardColor: Colors.white,
  // ... other properties
)
```

**Dynamic Theme Usage:**

```dart
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;
final textColor = isDark ? Colors.white : Colors.black;
```

### Theme Persistence

- Theme preference saved to SharedPreferences
- Loaded on app start via ThemeProvider
- Defaults to dark mode

---

## Data Persistence

### SharedPreferences Storage

**Stored Data:**

1. `token` (String) - JWT authentication token
2. `userId` (String) - User ID for profile fetching
3. `isDarkMode` (bool) - Theme preference

**Usage:**

```dart
// Save
final prefs = await SharedPreferences.getInstance();
await prefs.setString('token', token);

// Read
final token = prefs.getString('token');

// Clear (logout)
await prefs.clear();
```

### Session Management

- Token stored on login
- Token checked on app start
- Token cleared on logout
- Token automatically added to API requests via interceptor

---

## Error Handling

### Service Layer Error Handling

```dart
try {
  final response = await _apiService.client.post('/endpoint', data: data);
  return response.data;
} catch (e) {
  if (e is DioException) {
    // Extract error message from API response
    final errorMessage = e.response?.data['error'] ?? 'Default error message';
    throw Exception(errorMessage);
  }
  throw Exception('Unexpected error');
}
```

### UI Layer Error Handling

```dart
try {
  await provider.someMethod();
  // Show success message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Success!')),
  );
} catch (e) {
  // Show error message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.toString())),
  );
}
```

---

## UI/UX Features

### Pull-to-Refresh

Implemented on:

- Home View (transaction list)
- Monthly Stats Screen
- Wallet Screen

**Implementation:**

```dart
RefreshIndicator(
  onRefresh: _onRefresh,
  child: ListView(...),
)

Future<void> _onRefresh() async {
  await provider.fetchData();
}
```

### Infinite Scroll

Implemented on Home View for transaction pagination.

**Implementation:**

```dart
_scrollController.addListener(() {
  if (_scrollController.position.pixels >=
      _scrollController.position.maxScrollExtent - 200) {
    _loadMore();
  }
});

void _loadMore() {
  if (!provider.isLoading) {
    provider.fetchTransactions(page: provider.currentPage + 1);
  }
}
```

### Loading States

- Circular progress indicators during API calls
- Button loading states (spinner replaces text)
- Skeleton screens for initial loads

### Form Validation

- Real-time validation on text input
- Visual error messages below fields
- Submit button disabled during validation errors

### Responsive Design

- Adapts to different screen sizes
- Uses MediaQuery for responsive layouts
- Flexible layouts with Expanded and Flexible widgets

### Animations

- Page transitions using PageView
- Smooth tab switching with AnimatedContainer
- Fade-in animations for images

---

## Category System

### Supported Categories

1. **Food**
   - Icon: Coffee cup
   - Color: Teal
   - Description: "Groceries & Dining"

2. **Travel**
   - Icon: Car
   - Color: Orange
   - Description: "Commute & Trips"

3. **Shopping**
   - Icon: Shopping bag
   - Color: Purple
   - Description: "Personal Items"

4. **Bills**
   - Icon: Receipt
   - Color: Red (#FF5252)
   - Description: "Utilities & Fees"

5. **Rent**
   - Icon: Home
   - Color: Indigo
   - Description: "Housing & Rent"

6. **Other**
   - Icon: Category
   - Color: Blue Grey
   - Description: "General"

### Category Implementation

```dart
IconData _getCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'food': return Icons.local_cafe;
    case 'travel': return Icons.directions_car;
    // ... other cases
    default: return Icons.category;
  }
}

Color _getCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'food': return Colors.teal;
    case 'travel': return Colors.orange;
    // ... other cases
    default: return Colors.blueGrey;
  }
}
```

---

## Testing

### Test Structure

```
test/
├── models/
│   ├── transaction_model_test.dart
│   └── user_model_test.dart
├── providers/
│   ├── auth_provider_test.dart
│   ├── auth_provider_test.mocks.dart
│   ├── expense_provider_test.dart
│   └── expense_provider_test.mocks.dart
├── services/
│   ├── api_service_test.dart
│   ├── api_service_test.mocks.dart
│   ├── auth_service_test.dart
│   ├── auth_service_test.mocks.dart
│   ├── expense_service_test.dart
│   └── expense_service_test.mocks.dart
└── utils/
    └── validation_test.dart
```

### Testing Tools

- **flutter_test**: Flutter's testing framework
- **mockito**: Mocking library for unit tests
- **build_runner**: Code generation for mocks

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/auth_service_test.dart

# Run with coverage
flutter test --coverage

# Generate mocks
flutter pub run build_runner build
```

### Test Coverage Areas

1. **Model Tests**: JSON serialization/deserialization
2. **Service Tests**: API call mocking and response handling
3. **Provider Tests**: State management logic
4. **Validation Tests**: Form validation rules

---

## Dependencies

### Production Dependencies

**Core:**

- `flutter`: SDK
- `cupertino_icons: ^1.0.8`: iOS-style icons

**State Management:**

- `provider: ^6.1.1`: State management solution

**Networking:**

- `dio: ^5.4.0`: HTTP client for API calls
- `http_parser: ^4.0.0`: HTTP parsing utilities

**Storage:**

- `shared_preferences: ^2.2.2`: Local key-value storage

**Utilities:**

- `intl: ^0.19.0`: Internationalization and date formatting

**Authentication:**

- `flutter_web_auth_2: ^5.0.1`: OAuth web authentication

**Media:**

- `image_picker: ^1.0.7`: Image selection from gallery/camera

**External:**

- `url_launcher: ^6.3.2`: Launch URLs (email, web, etc.)

### Development Dependencies

**Testing:**

- `flutter_test`: SDK testing framework
- `test: ^1.26.0`: Dart testing library
- `mockito: ^5.6.3`: Mocking framework
- `build_runner: ^2.11.0`: Code generation

**Assets:**

- `flutter_native_splash: ^2.4.0`: Native splash screen generation
- `flutter_launcher_icons: ^0.13.1`: App icon generation

**Code Quality:**

- `flutter_lints: ^3.0.0`: Linting rules

---

## Build Configuration

### App Information

- **Name**: Spendwise
- **Package**: com.example.expenses
- **Version**: 1.0.0+1
- **SDK**: ^3.10.3

### Platform Support

- Android
- iOS
- Web
- Windows
- macOS
- Linux

### Splash Screen Configuration

```yaml
flutter_native_splash:
  color: "#ffffff"
  image: assets/images/logo.png
  android_12:
    image: assets/images/logo.png
    color: "#ffffff"
  fullscreen: true
```

### App Icon Configuration

```yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/images/logo.png"
  adaptive_icon_background: "#ffffff"
  adaptive_icon_foreground: "assets/images/logo.png"
```

### Assets

```yaml
assets:
  - assets/images/logo.png
```

---

## Setup Instructions

### Prerequisites

- Flutter SDK 3.10.3 or higher
- Dart SDK
- Android Studio / Xcode (for mobile development)
- VS Code or Android Studio (IDE)

### Installation Steps

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd expenses
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure API endpoint**
   Edit `lib/utils/constants.dart`:

   ```dart
   static const String baseUrl = 'YOUR_API_URL';
   ```

4. **Generate splash screen and icons**

   ```bash
   flutter pub run flutter_native_splash:create
   flutter pub run flutter_launcher_icons
   ```

5. **Run the app**

   ```bash
   # Development mode
   flutter run

   # Release mode
   flutter run --release
   ```

### Platform-Specific Setup

**Android:**

- Minimum SDK: 21
- Target SDK: 34
- Gradle: 8.x

**iOS:**

- Minimum iOS version: 12.0
- Xcode 14+

**Web:**

- No additional setup required

---

## Environment Configuration

### Development

```dart
// lib/utils/constants.dart
static const String baseUrl = 'http://localhost:4001/api/v1';
```

### Production

```dart
// lib/utils/constants.dart
static const String baseUrl = 'https://api-00fb.onrender.com/api/v1';
```

### Google OAuth Configuration

Update callback URL scheme in:

- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

Callback scheme: `spendwise`

---

## Code Quality & Best Practices

### Architecture Principles

1. **Separation of Concerns**: Models, Services, Providers, and UI are clearly separated
2. **Single Responsibility**: Each class has one clear purpose
3. **Dependency Injection**: Services are injected into providers for testability
4. **Immutability**: Models use `copyWith` for updates instead of mutation

### Code Organization

- Related files grouped in folders
- Consistent naming conventions
- Clear file structure matching feature domains

### State Management Best Practices

- Use `listen: false` when not rebuilding UI
- Call `notifyListeners()` after state changes
- Avoid unnecessary rebuilds with Consumer widget
- Keep business logic in providers, not UI

### Error Handling

- Try-catch blocks in all async operations
- User-friendly error messages
- Graceful degradation on API failures
- Loading states during operations

### Performance Optimizations

- Pagination for large lists
- Image caching with NetworkImage
- Lazy loading with ListView.builder
- Debouncing for search/filter operations

### Security Considerations

- JWT tokens stored securely in SharedPreferences
- Tokens automatically included in requests
- Password validation enforces strong passwords
- No sensitive data logged in production

---

## Known Issues & Limitations

### Current Limitations

1. **Offline Support**: No offline data caching (requires internet connection)
2. **Currency**: Only USD supported (hardcoded)
3. **Language**: English only (no internationalization)
4. **Scan Feature**: QR code scanning not implemented
5. **Security Settings**: Security page is placeholder

### Deprecation Warnings

- `withOpacity()` deprecated in favor of `withValues()`
- `activeColor` deprecated in Switch widget
- Some print statements should use logging framework

### Future Enhancements

1. Offline mode with local database (SQLite/Hive)
2. Multi-currency support
3. Budget setting and alerts
4. Recurring transactions
5. Export data (CSV/PDF)
6. Charts and advanced analytics
7. Biometric authentication
8. Receipt scanning with OCR
9. Multi-language support
10. Expense sharing with other users

---

## Troubleshooting

### Common Issues

**1. API Connection Failed**

- Check internet connection
- Verify API base URL in constants.dart
- Check if backend server is running
- Verify CORS settings on backend

**2. Login Not Persisting**

- Clear app data and try again
- Check if token is being saved to SharedPreferences
- Verify checkAuthStatus() is called in main()

**3. Images Not Loading**

- Check network permissions
- Verify image URLs are valid
- Check if NetworkImage is properly configured

**4. Build Errors**

- Run `flutter clean`
- Run `flutter pub get`
- Delete `build` folder and rebuild
- Check Flutter and Dart SDK versions

**5. Google OAuth Not Working**

- Verify callback URL scheme configuration
- Check Google OAuth credentials
- Ensure backend OAuth endpoint is correct

### Debug Commands

```bash
# Check Flutter installation
flutter doctor

# Clean build files
flutter clean

# Get dependencies
flutter pub get

# Run with verbose logging
flutter run -v

# Check for outdated packages
flutter pub outdated
```

---

## API Backend Requirements

### Expected Backend Structure

The Flutter app expects a REST API with the following characteristics:

**Authentication:**

- JWT-based authentication
- Token returned on login/register
- Token validation on protected routes

**Response Format:**

```json
{
  "success": true,
  "data": { ... },
  "error": "Error message if any"
}
```

**Error Handling:**

- HTTP status codes (200, 400, 401, 404, 500)
- Error messages in response body
- Consistent error format

**Pagination:**

```json
{
  "docs": [...],
  "totalDocs": 100,
  "limit": 10,
  "page": 1,
  "totalPages": 10
}
```

### Database Schema

**User Collection:**

```javascript
{
  _id: ObjectId,
  email: String (unique),
  username: String,
  password: String (hashed),
  avatar: String (URL),
  createdAt: Date,
  updatedAt: Date
}
```

**Transaction Collection:**

```javascript
{
  _id: ObjectId,
  user: ObjectId (ref: User),
  amount: Number,
  category: String,
  description: String,
  date: Date,
  createdAt: Date,
  updatedAt: Date
}
```

**Wallet Collection:**

```javascript
{
  _id: ObjectId,
  user: ObjectId (ref: User),
  balance: Number,
  createdAt: Date,
  updatedAt: Date
}
```

---

## Deployment

### Building for Production

**Android APK:**

```bash
flutter build apk --release
```

**Android App Bundle:**

```bash
flutter build appbundle --release
```

**iOS:**

```bash
flutter build ios --release
```

**Web:**

```bash
flutter build web --release
```

### Release Checklist

- [ ] Update version in pubspec.yaml
- [ ] Set production API URL
- [ ] Remove debug print statements
- [ ] Test on physical devices
- [ ] Test all authentication flows
- [ ] Test offline behavior
- [ ] Verify all API endpoints
- [ ] Check app permissions
- [ ] Test on different screen sizes
- [ ] Generate release builds
- [ ] Test release builds
- [ ] Prepare store listings
- [ ] Create screenshots
- [ ] Write release notes

### App Store Submission

**Google Play Store:**

1. Create app listing
2. Upload app bundle
3. Set up content rating
4. Configure pricing
5. Submit for review

**Apple App Store:**

1. Create app in App Store Connect
2. Upload build via Xcode
3. Fill app information
4. Submit for review

---

## Contributing Guidelines

### Code Style

- Follow Dart style guide
- Use meaningful variable names
- Add comments for complex logic
- Keep functions small and focused
- Use const constructors where possible

### Git Workflow

1. Create feature branch from main
2. Make changes with clear commit messages
3. Test thoroughly
4. Create pull request
5. Code review
6. Merge to main

### Commit Message Format

```
type(scope): subject

body (optional)

footer (optional)
```

**Types:**

- feat: New feature
- fix: Bug fix
- docs: Documentation
- style: Formatting
- refactor: Code restructuring
- test: Adding tests
- chore: Maintenance

**Example:**

```
feat(auth): add Google OAuth login

Implemented Google OAuth authentication flow using flutter_web_auth_2.
Users can now sign in with their Google account.

Closes #123
```

### Pull Request Template

```markdown
## Description

Brief description of changes

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing

- [ ] Unit tests added/updated
- [ ] Manual testing completed
- [ ] Tested on Android
- [ ] Tested on iOS

## Screenshots (if applicable)

Add screenshots here

## Checklist

- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings generated
```

---

## License

This project is licensed under the MIT License.

---

## Contact & Support

**Developer:** Oeun Nuphea  
**Email:** oeunnuphea@gmail.com

**Support Channels:**

- Email: oeunnuphea@gmail.com
- In-app Help & Support section

---

## Changelog

### Version 1.0.0 (Current)

**Features:**

- User authentication (Email/Password & Google OAuth)
- Transaction management (CRUD operations)
- Category-based expense tracking
- Monthly and daily statistics
- Digital wallet management
- Profile management with avatar upload
- Dark/Light theme support
- Pull-to-refresh functionality
- Infinite scroll pagination
- Responsive UI design

**Known Issues:**

- No offline support
- Single currency (USD only)
- Some deprecation warnings

---

## Appendix

### Useful Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Provider Package](https://pub.dev/packages/provider)
- [Dio Package](https://pub.dev/packages/dio)
- [Material Design Guidelines](https://material.io/design)

### Development Tools

- **IDE**: VS Code / Android Studio
- **State Inspector**: Flutter DevTools
- **API Testing**: Postman
- **Version Control**: Git

### Color Palette

- Primary: `#00BFA5` (Teal)
- Error: `#FF5252` (Red)
- Background Light: `#F2F4F7`
- Background Dark: `#121212`
- Card Light: `#FFFFFF`
- Card Dark: `#1E1E1E`

### Typography

- Font Family: System default (Roboto on Android, SF Pro on iOS)
- Title: 32px, Bold
- Heading: 22px, Bold
- Body: 16px, Regular
- Caption: 12px, Regular

---

**Document Version:** 1.0  
**Last Updated:** February 10, 2026  
**Generated for:** Spendwise v1.0.0

---

_This documentation provides a comprehensive overview of the Spendwise expense tracking application. For specific implementation details, refer to the source code and inline comments._
