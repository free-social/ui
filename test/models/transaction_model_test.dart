import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/models/transaction_model.dart';

void main() {
  group('TransactionModel', () {
    
    // 1. Define a sample JSON object (simulating data from your API)
    final Map<String, dynamic> tTransactionJson = {
      'id': 'trans_123', // Used for fromJson
      'amount': 4.50,
      'category': 'Food',
      'description': 'Coffee at Starbucks',
      'date': '2023-10-01T08:30:00.000',
    };

    // 2. Define the expected Dart Object
    final tTransactionModel = TransactionModel(
      id: 'trans_123',
      amount: 4.50,
      category: 'Food',
      description: 'Coffee at Starbucks',
      date: DateTime.parse('2023-10-01T08:30:00.000'),
    );

    test('fromJson should return a valid model from JSON', () {
      // ACT
      final result = TransactionModel.fromJson(tTransactionJson);

      // ASSERT
      expect(result.id, tTransactionModel.id);
      expect(result.amount, tTransactionModel.amount);
      expect(result.description, tTransactionModel.description);
      expect(result.date, tTransactionModel.date);
    });

    test('fromJson should support MongoDB "_id" field', () {
      // Arrange: specific Mongo style JSON
      final mongoJson = {
        '_id': 'mongo_123',
        'amount': 10.0,
        'category': 'Test',
        'description': 'Test',
        'date': DateTime.now().toIso8601String(),
      };

      // Act
      final result = TransactionModel.fromJson(mongoJson);

      // Assert
      expect(result.id, 'mongo_123');
    });

    test('toJson should return a JSON map (excluding ID)', () {
      // ACT
      final result = tTransactionModel.toJson();

      // ASSERT
      // We create a copy of the input map and remove 'id' 
      // because your model's toJson() does not include it.
      final expectedMap = Map<String, dynamic>.from(tTransactionJson);
      expectedMap.remove('id'); 

      expect(result, expectedMap);
    });
  });
}