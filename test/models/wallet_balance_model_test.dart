import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/models/wallet_balance_model.dart';

void main() {
  group('WalletBalanceModel', () {
    // --- 1. JSON Deserialization Tests ---

    test('fromJson creates a valid wallet balance from standard JSON', () {
      final json = {'_id': 'wallet123', 'balance': 500.50, 'user': 'user456'};

      final walletBalance = WalletBalanceModel.fromJson(json);

      expect(walletBalance.id, 'wallet123');
      expect(walletBalance.balance, 500.50);
      expect(walletBalance.userId, 'user456');
    });

    test('fromJson handles integer balance and converts to double', () {
      final json = {
        '_id': 'wallet123',
        'balance': 100, // Integer
        'user': 'user456',
      };

      final walletBalance = WalletBalanceModel.fromJson(json);

      expect(walletBalance.balance, 100.0);
      expect(walletBalance.balance, isA<double>());
    });

    test('fromJson handles missing fields with default values', () {
      // Scenario: API returns a partial or empty object
      final Map<String, dynamic> json = {};

      final walletBalance = WalletBalanceModel.fromJson(json);

      // Should default to empty strings and 0.0 per the model logic
      expect(walletBalance.id, '');
      expect(walletBalance.balance, 0.0);
      expect(walletBalance.userId, '');
    });

    test('fromJson handles null balance field', () {
      final json = {'_id': 'wallet123', 'balance': null, 'user': 'user456'};

      final walletBalance = WalletBalanceModel.fromJson(json);

      expect(walletBalance.id, 'wallet123');
      expect(walletBalance.balance, 0.0);
      expect(walletBalance.userId, 'user456');
    });

    test('fromJson handles missing _id field', () {
      final json = {'balance': 250.75, 'user': 'user789'};

      final walletBalance = WalletBalanceModel.fromJson(json);

      expect(walletBalance.id, '');
      expect(walletBalance.balance, 250.75);
      expect(walletBalance.userId, 'user789');
    });

    test('fromJson handles missing user field', () {
      final json = {'_id': 'wallet123', 'balance': 150.25};

      final walletBalance = WalletBalanceModel.fromJson(json);

      expect(walletBalance.id, 'wallet123');
      expect(walletBalance.balance, 150.25);
      expect(walletBalance.userId, '');
    });

    // --- 2. Constructor Tests ---

    test('constructor creates valid instance', () {
      final walletBalance = WalletBalanceModel(
        id: 'w123',
        balance: 999.99,
        userId: 'u456',
      );

      expect(walletBalance.id, 'w123');
      expect(walletBalance.balance, 999.99);
      expect(walletBalance.userId, 'u456');
    });

    test('constructor handles zero balance', () {
      final walletBalance = WalletBalanceModel(
        id: 'w123',
        balance: 0.0,
        userId: 'u456',
      );

      expect(walletBalance.balance, 0.0);
    });

    test('constructor handles negative balance', () {
      final walletBalance = WalletBalanceModel(
        id: 'w123',
        balance: -50.25,
        userId: 'u456',
      );

      expect(walletBalance.balance, -50.25);
    });
  });
}
