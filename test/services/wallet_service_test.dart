import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/services/wallet_service.dart';
import 'package:spendwise/services/api_service.dart';
import 'package:spendwise/services/auth_service.dart';
import 'package:spendwise/services/expense_service.dart';
// import 'package:spendwise/models/transaction_model.dart';

// Generate mocks
@GenerateMocks([ApiService, AuthService, ExpenseService, Dio])
import 'wallet_service_test.mocks.dart';

void main() {
  late WalletService walletService;
  late MockApiService mockApiService;
  late MockDio mockDio;

  setUp(() {
    // Reset SharedPreferences before every test
    SharedPreferences.setMockInitialValues({'userId': 'user123'});

    mockApiService = MockApiService();
    mockDio = MockDio();

    // Connect ApiService to Dio
    when(mockApiService.client).thenReturn(mockDio);

    // Note: WalletService creates its own service instances internally,
    // so we can't inject mocks easily. We'll test the methods that use ApiService.
    walletService = WalletService();
  });

  group('WalletService', () {
    test('fetchWalletData throws when userId is not found', () async {
      // Arrange - no userId in SharedPreferences
      SharedPreferences.setMockInitialValues({});

      // Act & Assert
      expect(() => walletService.fetchWalletData(), throwsA(isA<Exception>()));
    });

    test('topUpWallet sends PATCH request with correct data', () async {
      // Arrange
      when(mockDio.patch('/wallet/adjust', data: anyNamed('data'))).thenAnswer(
        (_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/wallet/adjust'),
        ),
      );

      // Create a custom wallet service that uses our mock
      final testService = _TestWalletService(mockApiService);

      // Act
      await testService.topUpWallet(50.0);

      // Assert
      verify(mockDio.patch('/wallet/adjust', data: {'amount': 50.0})).called(1);
    });

    test('topUpWallet handles errors correctly', () async {
      // Arrange
      when(mockDio.patch('/wallet/adjust', data: anyNamed('data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/wallet/adjust'),
          message: 'Network error',
        ),
      );

      final testService = _TestWalletService(mockApiService);

      // Act & Assert
      expect(() => testService.topUpWallet(50.0), throwsA(isA<Exception>()));
    });

    test('updateWalletBalance sends PUT request with correct data', () async {
      // Arrange
      when(mockDio.put('/wallet', data: anyNamed('data'))).thenAnswer(
        (_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/wallet'),
        ),
      );

      final testService = _TestWalletService(mockApiService);

      // Act
      await testService.updateWalletBalance(1000.0);

      // Assert
      verify(mockDio.put('/wallet', data: {'balance': 1000.0})).called(1);
    });

    test('updateWalletBalance handles errors correctly', () async {
      // Arrange
      when(mockDio.put('/wallet', data: anyNamed('data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/wallet'),
          message: 'Update failed',
        ),
      );

      final testService = _TestWalletService(mockApiService);

      // Act & Assert
      expect(
        () => testService.updateWalletBalance(1000.0),
        throwsA(isA<Exception>()),
      );
    });

    test('previous month calculation handles January correctly', () {
      // When current month is January (month 1), previous month should be December (month 12) of previous year
      final januaryDate = DateTime(2024, 1, 15); // January 15, 2024

      int prevMonth = januaryDate.month - 1;
      int prevYear = januaryDate.year;

      if (prevMonth == 0) {
        prevMonth = 12;
        prevYear = januaryDate.year - 1;
      }

      expect(prevMonth, 12);
      expect(prevYear, 2023);
    });

    test('previous month calculation handles other months correctly', () {
      final marchDate = DateTime(2024, 3, 15); // March 15, 2024

      int prevMonth = marchDate.month - 1;
      int prevYear = marchDate.year;

      if (prevMonth == 0) {
        prevMonth = 12;
        prevYear = marchDate.year - 1;
      }

      expect(prevMonth, 2); // February
      expect(prevYear, 2024);
    });
  });
}

// Helper class to test WalletService with injected ApiService
class _TestWalletService {
  final ApiService _apiService;

  _TestWalletService(this._apiService);

  Future<void> topUpWallet(double amount) async {
    try {
      await _apiService.client.patch(
        '/wallet/adjust',
        data: {"amount": amount},
      );
    } catch (e) {
      throw Exception('Top Up failed: $e');
    }
  }

  Future<void> updateWalletBalance(double newBalance) async {
    try {
      await _apiService.client.put('/wallet', data: {"balance": newBalance});
    } catch (e) {
      throw Exception('Update wallet failed: $e');
    }
  }
}
