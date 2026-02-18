import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import '../helpers/mock_http_overrides.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:spendwise/providers/expense_provider.dart';
import 'package:spendwise/services/expense_service.dart';
import 'package:spendwise/models/transaction_model.dart';

// Generate the mock for ExpenseService
@GenerateMocks([ExpenseService])
import 'expense_provider_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = MockHttpOverrides();
  });

  late ExpenseProvider provider;
  late MockExpenseService mockService;

  // Sample Data
  final tTransaction = TransactionModel(
    id: '1',
    amount: 50.0,
    category: 'Food',
    description: 'Lunch',
    date: DateTime.now(),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockService = MockExpenseService();
    provider = ExpenseProvider(expenseService: mockService);
  });

  group('ExpenseProvider', () {
    test('initial state should be empty', () {
      expect(provider.transactions, []);
      expect(provider.isLoading, false);
    });

    test('fetchTransactions populates the list (Page 1)', () async {
      // ARRANGE
      when(
        mockService.getAllTransactions(
          page: anyNamed('page'), // Use anyNamed for flexibility
          limit: anyNamed('limit'),
          category: anyNamed('category'),
          sortBy: anyNamed('sortBy'),
          sortOrder: anyNamed('sortOrder'),
        ),
      ).thenAnswer((_) async => [tTransaction]);

      // ACT
      await provider.fetchTransactions(page: 1);

      // ASSERT
      expect(provider.transactions.length, 1);
      expect(provider.transactions.first.description, 'Lunch');
      expect(provider.isLoading, false);
    });

    test('deleteTransaction removes item from list', () async {
      // ARRANGE
      // 1. Pre-load data
      when(
        mockService.getAllTransactions(
          page: anyNamed('page'),
          limit: anyNamed('limit'),
          category: anyNamed('category'),
          sortBy: anyNamed('sortBy'),
          sortOrder: anyNamed('sortOrder'),
        ),
      ).thenAnswer((_) async => [tTransaction]);

      await provider.fetchTransactions(page: 1);
      expect(provider.transactions.length, 1); // Check data exists

      // 2. Mock Delete (Void return)
      // ✅ FIX: Use 'null' for void functions, NOT '{}'
      when(mockService.deleteTransaction('1')).thenAnswer((_) async => null);

      // ACT
      await provider.deleteTransaction('1');

      // ASSERT
      expect(provider.transactions.isEmpty, true);
    });

    test('addTransaction calls service and refreshes list', () async {
      // ARRANGE
      // ✅ FIX: Return 'tTransaction' (Model), NOT '{}' (Map)
      when(
        mockService.createTransaction(any),
      ).thenAnswer((_) async => tTransaction);

      // Mock the fetch call that happens automatically after adding
      when(
        mockService.getAllTransactions(
          page: anyNamed('page'),
          limit: anyNamed('limit'),
          category: anyNamed('category'),
          sortBy: anyNamed('sortBy'),
          sortOrder: anyNamed('sortOrder'),
        ),
      ).thenAnswer((_) async => [tTransaction]);

      // ACT
      await provider.addTransaction(50.0, 'Food', 'Lunch', DateTime.now());

      // ASSERT
      verify(mockService.createTransaction(any)).called(1);

      // Verify fetch was called again
      verify(
        mockService.getAllTransactions(
          page: anyNamed('page'),
          limit: anyNamed('limit'),
          category: anyNamed('category'),
          sortBy: anyNamed('sortBy'),
          sortOrder: anyNamed('sortOrder'),
        ),
      ).called(greaterThan(0));
    });
  });
}
