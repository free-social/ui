import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
// REPLACE with your actual package name
import 'package:spendwise/services/expense_service.dart';
import 'package:spendwise/services/api_service.dart';
import 'package:spendwise/models/transaction_model.dart';

// ✅ Generate mocks for BOTH classes
@GenerateMocks([ApiService, Dio])
import 'expense_service_test.mocks.dart';

void main() {
  late ExpenseService expenseService;
  late MockApiService mockApiService;
  late MockDio mockDio;

  setUp(() {
    mockApiService = MockApiService();
    mockDio = MockDio();

    // ✅ CRITICAL: Tell the MockApiService to return our MockDio
    // whenever .client is called.
    when(mockApiService.client).thenReturn(mockDio);

    expenseService = ExpenseService(apiService: mockApiService);
  });

  group('ExpenseService', () {
    final tTransactionJson = {
      'id': '1',
      'amount': 100.0,
      'category': 'Food',
      'description': 'Dinner',
      'date': '2023-10-01T20:00:00.000',
    };
    
    final tTransaction = TransactionModel.fromJson(tTransactionJson);

    test('getAllTransactions handles standard list response', () async {
      // ARRANGE
      final responsePayload = [tTransactionJson]; // API returns List
      
      when(mockDio.get(
        any, 
        queryParameters: anyNamed('queryParameters')
      )).thenAnswer((_) async => Response(
        data: responsePayload, 
        statusCode: 200, 
        requestOptions: RequestOptions(path: '/transactions')
      ));

      // ACT
      final result = await expenseService.getAllTransactions();

      // ASSERT
      expect(result, isA<List<TransactionModel>>());
      expect(result.length, 1);
      expect(result.first.amount, 100.0);
    });

    test('getAllTransactions handles Mongoose pagination ({docs: [...]})', () async {
      // ARRANGE
      final responsePayload = {
        'docs': [tTransactionJson], // API returns Map with docs
        'totalDocs': 1,
        'page': 1
      };
      
      when(mockDio.get(
        any, 
        queryParameters: anyNamed('queryParameters')
      )).thenAnswer((_) async => Response(
        data: responsePayload, 
        statusCode: 200, 
        requestOptions: RequestOptions(path: '/transactions')
      ));

      // ACT
      final result = await expenseService.getAllTransactions();

      // ASSERT
      expect(result.length, 1);
      expect(result.first.category, 'Food');
    });

    test('createTransaction posts data and returns model', () async {
      // ARRANGE
      when(mockDio.post(
        '/transactions', 
        data: anyNamed('data')
      )).thenAnswer((_) async => Response(
        data: tTransactionJson, // Server returns the created object
        statusCode: 201, 
        requestOptions: RequestOptions(path: '/transactions')
      ));

      // ACT
      final result = await expenseService.createTransaction(tTransaction);

      // ASSERT
      expect(result, isA<TransactionModel>());
      expect(result.id, '1');
      verify(mockDio.post('/transactions', data: anyNamed('data'))).called(1);
    });

    test('deleteTransaction sends delete request', () async {
      // ARRANGE
      when(mockDio.delete(any)).thenAnswer((_) async => Response(
        data: {}, 
        statusCode: 200, 
        requestOptions: RequestOptions(path: '/transactions/1')
      ));

      // ACT
      await expenseService.deleteTransaction('1');

      // ASSERT
      verify(mockDio.delete('/transactions/1')).called(1);
    });
    
    test('Throws exception when API fails', () async {
      // ARRANGE
      when(mockDio.get(any, queryParameters: anyNamed('queryParameters')))
          .thenThrow(DioException(
            requestOptions: RequestOptions(path: '/transactions'),
            error: 'Server Error'
          ));

      // ACT & ASSERT
      expect(
        () => expenseService.getAllTransactions(), 
        throwsException
      );
    });
  });
}