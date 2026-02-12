import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:spendwise/providers/wallet_provider.dart';
import 'package:spendwise/services/wallet_service.dart';
import 'package:spendwise/services/expense_service.dart';
import 'package:spendwise/models/user_model.dart';
import 'package:spendwise/models/transaction_model.dart';
import 'package:spendwise/models/wallet_balance_model.dart';

// Generate mocks for WalletService and ExpenseService
@GenerateMocks([WalletService, ExpenseService])
import 'wallet_provider_test.mocks.dart';

void main() {
  late WalletProvider walletProvider;
  late MockWalletService mockWalletService;
  late MockExpenseService mockExpenseService;

  setUp(() {
    mockWalletService = MockWalletService();
    mockExpenseService = MockExpenseService();
    walletProvider = WalletProvider(
      walletService: mockWalletService,
      expenseService: mockExpenseService,
    );
  });

  group('WalletProvider', () {
    test('initial state is correct', () {
      expect(walletProvider.walletData, null);
      expect(walletProvider.lastMonthExpense, 0.0);
      expect(walletProvider.isLoading, false);
      expect(walletProvider.error, null);
    });

    test('fetchWalletData sets loading state correctly', () async {
      // Arrange
      final walletData = WalletData(
        user: User(
          id: '1',
          email: 'test@test.com',
          username: 'Test',
          avatar: '',
        ),
        transactions: [],
        walletBalance: WalletBalanceModel(
          id: 'w1',
          balance: 100.0,
          userId: 'u1',
        ),
        lastMonthExpense: 50.0,
      );

      when(
        mockWalletService.fetchWalletData(),
      ).thenAnswer((_) async => walletData);
      when(
        mockExpenseService.getMonthlyExpenseTotal(any, any),
      ).thenAnswer((_) async => 50.0);

      // Act
      final future = walletProvider.fetchWalletData();

      // Assert - loading should be true immediately
      expect(walletProvider.isLoading, true);

      await future;

      // Assert - loading should be false after completion
      expect(walletProvider.isLoading, false);
    });

    test('fetchWalletData success populates wallet data', () async {
      // Arrange
      final user = User(
        id: '1',
        email: 'test@test.com',
        username: 'Test',
        avatar: '',
      );
      final transactions = <TransactionModel>[
        TransactionModel(
          id: 't1',
          description: 'Test',
          amount: 10.0,
          category: 'food',
          date: DateTime.now(),
        ),
      ];
      final walletBalance = WalletBalanceModel(
        id: 'w1',
        balance: 500.0,
        userId: 'u1',
      );
      final walletData = WalletData(
        user: user,
        transactions: transactions,
        walletBalance: walletBalance,
        lastMonthExpense: 200.0,
      );

      when(
        mockWalletService.fetchWalletData(),
      ).thenAnswer((_) async => walletData);
      when(
        mockExpenseService.getMonthlyExpenseTotal(any, any),
      ).thenAnswer((_) async => 200.0);

      // Act
      await walletProvider.fetchWalletData();

      // Assert
      expect(walletProvider.walletData, isNotNull);
      expect(walletProvider.walletData?.user.id, '1');
      expect(walletProvider.walletData?.transactions.length, 1);
      expect(walletProvider.walletData?.walletBalance.balance, 500.0);
      expect(walletProvider.lastMonthExpense, 200.0);
      expect(walletProvider.error, null);
    });

    test('fetchWalletData handles errors correctly', () async {
      // Arrange
      when(
        mockWalletService.fetchWalletData(),
      ).thenThrow(Exception('Network error'));

      // Act
      await walletProvider.fetchWalletData();

      // Assert
      expect(walletProvider.error, isNotNull);
      expect(walletProvider.error, contains('Network error'));
      expect(walletProvider.isLoading, false);
      expect(walletProvider.walletData, null);
    });

    test('topUpWallet calls service and refreshes data', () async {
      // Arrange
      final walletData = WalletData(
        user: User(
          id: '1',
          email: 'test@test.com',
          username: 'Test',
          avatar: '',
        ),
        transactions: [],
        walletBalance: WalletBalanceModel(
          id: 'w1',
          balance: 600.0,
          userId: 'u1',
        ),
        lastMonthExpense: 50.0,
      );

      when(
        mockWalletService.topUpWallet(100.0),
      ).thenAnswer((_) async => Future.value());
      when(
        mockWalletService.fetchWalletData(),
      ).thenAnswer((_) async => walletData);
      when(
        mockExpenseService.getMonthlyExpenseTotal(any, any),
      ).thenAnswer((_) async => 50.0);

      // Act
      await walletProvider.topUpWallet(100.0);

      // Assert
      verify(mockWalletService.topUpWallet(100.0)).called(1);
      verify(mockWalletService.fetchWalletData()).called(1);
      expect(walletProvider.walletData?.walletBalance.balance, 600.0);
    });

    test('topUpWallet handles errors and sets error state', () async {
      // Arrange
      when(
        mockWalletService.topUpWallet(100.0),
      ).thenThrow(Exception('Top up failed'));

      // Act & Assert
      expect(
        () => walletProvider.topUpWallet(100.0),
        throwsA(isA<Exception>()),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(walletProvider.error, isNotNull);
      expect(walletProvider.error, contains('Top up failed'));
    });

    test('updateWalletBalance calls service and refreshes data', () async {
      // Arrange
      final walletData = WalletData(
        user: User(
          id: '1',
          email: 'test@test.com',
          username: 'Test',
          avatar: '',
        ),
        transactions: [],
        walletBalance: WalletBalanceModel(
          id: 'w1',
          balance: 1000.0,
          userId: 'u1',
        ),
        lastMonthExpense: 50.0,
      );

      when(
        mockWalletService.updateWalletBalance(1000.0),
      ).thenAnswer((_) async => Future.value());
      when(
        mockWalletService.fetchWalletData(),
      ).thenAnswer((_) async => walletData);
      when(
        mockExpenseService.getMonthlyExpenseTotal(any, any),
      ).thenAnswer((_) async => 50.0);

      // Act
      await walletProvider.updateWalletBalance(1000.0);

      // Assert
      verify(mockWalletService.updateWalletBalance(1000.0)).called(1);
      verify(mockWalletService.fetchWalletData()).called(1);
      expect(walletProvider.walletData?.walletBalance.balance, 1000.0);
    });

    test('updateWalletBalance handles errors and sets error state', () async {
      // Arrange
      when(
        mockWalletService.updateWalletBalance(1000.0),
      ).thenThrow(Exception('Update failed'));

      // Act & Assert
      expect(
        () => walletProvider.updateWalletBalance(1000.0),
        throwsA(isA<Exception>()),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(walletProvider.error, isNotNull);
      expect(walletProvider.error, contains('Update failed'));
    });

    test('refreshData calls fetchWalletData', () async {
      // Arrange
      final walletData = WalletData(
        user: User(
          id: '1',
          email: 'test@test.com',
          username: 'Test',
          avatar: '',
        ),
        transactions: [],
        walletBalance: WalletBalanceModel(
          id: 'w1',
          balance: 500.0,
          userId: 'u1',
        ),
        lastMonthExpense: 50.0,
      );

      when(
        mockWalletService.fetchWalletData(),
      ).thenAnswer((_) async => walletData);
      when(
        mockExpenseService.getMonthlyExpenseTotal(any, any),
      ).thenAnswer((_) async => 50.0);

      // Act
      await walletProvider.refreshData();

      // Assert
      verify(mockWalletService.fetchWalletData()).called(1);
    });

    test('clearError resets error to null', () async {
      // Arrange - set an error first
      when(
        mockWalletService.fetchWalletData(),
      ).thenThrow(Exception('Test error'));
      await walletProvider.fetchWalletData();

      expect(walletProvider.error, isNotNull);

      // Act
      walletProvider.clearError();

      // Assert
      expect(walletProvider.error, null);
    });

    test('notifyListeners is called on state changes', () async {
      // Arrange
      bool notified = false;
      walletProvider.addListener(() {
        notified = true;
      });

      final walletData = WalletData(
        user: User(
          id: '1',
          email: 'test@test.com',
          username: 'Test',
          avatar: '',
        ),
        transactions: [],
        walletBalance: WalletBalanceModel(
          id: 'w1',
          balance: 500.0,
          userId: 'u1',
        ),
        lastMonthExpense: 50.0,
      );

      when(
        mockWalletService.fetchWalletData(),
      ).thenAnswer((_) async => walletData);
      when(
        mockExpenseService.getMonthlyExpenseTotal(any, any),
      ).thenAnswer((_) async => 50.0);

      // Act
      await walletProvider.fetchWalletData();

      // Assert
      expect(notified, true);
    });
  });
}
