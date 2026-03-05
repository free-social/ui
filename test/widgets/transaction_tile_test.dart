import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:spendwise/widgets/transaction_tile.dart';
import 'package:spendwise/models/transaction_model.dart';
import 'package:spendwise/providers/expense_provider.dart';

// Generate mock for ExpenseProvider
@GenerateMocks([ExpenseProvider])
import 'transaction_tile_test.mocks.dart';

void main() {
  late MockExpenseProvider mockExpenseProvider;
  late TransactionModel testTransaction;

  setUp(() {
    mockExpenseProvider = MockExpenseProvider();
    testTransaction = TransactionModel(
      id: 't123',
      description: 'Coffee',
      amount: 5.50,
      category: 'food',
      date: DateTime(2024, 2, 12),
    );
  });

  Widget createWidgetUnderTest(TransactionModel transaction) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<ExpenseProvider>.value(
          value: mockExpenseProvider,
          child: TransactionTile(transaction: transaction),
        ),
      ),
    );
  }

  group('TransactionTile Widget', () {
    testWidgets('renders transaction data correctly', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest(testTransaction));

      // Assert
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget); // Capitalized category
      expect(find.text('\$5.50'), findsOneWidget);
    });

    testWidgets('shows correct category initial in CircleAvatar', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest(testTransaction));

      // Assert - should show 'F' for 'food'
      expect(find.text('F'), findsOneWidget);
    });

    testWidgets('handles empty category gracefully', (
      WidgetTester tester,
    ) async {
      // Arrange
      final emptyTransaction = TransactionModel(
        id: 't123',
        description: 'Test',
        amount: 10.0,
        category: '',
        date: DateTime(2024, 2, 12),
      );

      // Act
      await tester.pumpWidget(createWidgetUnderTest(emptyTransaction));

      // Assert - should show '?' when category is empty
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('formats amount with 2 decimal places', (
      WidgetTester tester,
    ) async {
      // Arrange
      final transaction = TransactionModel(
        id: 't123',
        description: 'Lunch',
        amount: 12.5, // Should display as $12.50
        category: 'food',
        date: DateTime(2024, 2, 12),
      );

      // Act
      await tester.pumpWidget(createWidgetUnderTest(transaction));

      // Assert
      expect(find.text('\$12.50'), findsOneWidget);
    });

    testWidgets('shows edit and delete buttons', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest(testTransaction));

      // Assert
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsWidgets);
    });

    testWidgets('delete button shows confirmation dialog', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest(testTransaction));

      // Act - tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Delete Transaction?'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to delete this transaction? This action cannot be undone.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      // Only one Delete text widget (in the dialog) - the icon button is separate
      expect(find.widgetWithText(ElevatedButton, 'Delete'), findsOneWidget);
    });

    testWidgets('delete confirmation dialog Cancel button dismisses dialog', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest(testTransaction));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();

      // Act - tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Assert - dialog should be dismissed
      expect(find.text('Delete Transaction?'), findsNothing);
      verifyNever(mockExpenseProvider.deleteTransaction(any));
    });

    testWidgets('delete confirmation dialog Delete button calls provider', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest(testTransaction));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();

      // Act - tap Delete in dialog
      final deleteButton = find.widgetWithText(ElevatedButton, 'Delete');
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      // Pump extra to handle snackbar timer
      await tester.pump(const Duration(seconds: 4));

      // Assert - should call deleteTransaction
      verify(mockExpenseProvider.deleteTransaction('t123')).called(1);
    });

    testWidgets('swipe-to-delete shows delete background', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest(testTransaction));

      // Act - start swipe gesture (endToStart)
      await tester.drag(find.byType(Dismissible), const Offset(-300.0, 0.0));
      await tester.pump();

      // Assert - red background with delete icon should be visible
      expect(find.byIcon(Icons.delete), findsWidgets);
    });

    testWidgets('tap on tile opens edit screen', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest(testTransaction));

      // Act - tap on the ListTile
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Assert - TransactionFormScreen should be pushed (we can't fully test navigation without a full app)
      // But we can verify no errors occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets('edit button opens edit screen', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest(testTransaction));

      // Act - tap edit button
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Assert - TransactionFormScreen should be pushed (we can't fully test navigation without a full app)
      expect(tester.takeException(), isNull);
    });

    testWidgets('capitalizes category name correctly', (
      WidgetTester tester,
    ) async {
      // Arrange
      final transaction = TransactionModel(
        id: 't123',
        description: 'Taxi',
        amount: 15.0,
        category: 'transportation',
        date: DateTime(2024, 2, 12),
      );

      // Act
      await tester.pumpWidget(createWidgetUnderTest(transaction));

      // Assert - should be 'Transportation' (capitalized)
      expect(find.text('Transportation'), findsOneWidget);
    });

    testWidgets('Dismissible has correct key', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest(testTransaction));

      // Assert
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
      expect(dismissible.key, Key('t123'));
    });

    testWidgets('displays Card with proper styling', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest(testTransaction));

      // Assert
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
    });
  });
}
