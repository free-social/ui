import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// REPLACE with your actual package name
import 'package:spendwise/services/auth_service.dart';
import 'package:spendwise/services/api_service.dart';

// Generate mocks for ApiService and Dio
@GenerateMocks([ApiService, Dio])
import 'auth_service_test.mocks.dart';

void main() {
  late AuthService authService;
  late MockApiService mockApiService;
  late MockDio mockDio;

  setUp(() {
    // 1. Reset SharedPreferences before every test
    SharedPreferences.setMockInitialValues({});

    // 2. Setup Mocks
    mockApiService = MockApiService();
    mockDio = MockDio();

    // 3. Connect ApiService to Dio
    when(mockApiService.client).thenReturn(mockDio);

    // 4. Inject into AuthService
    authService = AuthService(apiService: mockApiService);
  });

  group('AuthService', () {
    
    test('login calls API and saves token/userId to SharedPreferences', () async {
      // ARRANGE
      final loginResponse = {
        'token': 'fake_token_abc',
        'user': {
          'id': 'user_123',
          'email': 'test@test.com'
        }
      };

      // Mock the POST request
      when(mockDio.post(
        '/auth/login', 
        data: anyNamed('data')
      )).thenAnswer((_) async => Response(
        data: loginResponse,
        statusCode: 200,
        requestOptions: RequestOptions(path: '/auth/login')
      ));

      // ACT
      await authService.login('test@test.com', 'password');

      // ASSERT 1: API was called
      verify(mockDio.post('/auth/login', data: anyNamed('data'))).called(1);

      // ASSERT 2: Data was saved to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('token'), 'fake_token_abc');
      expect(prefs.getString('userId'), 'user_123');
    });

    test('register calls API with correct data', () async {
      // ARRANGE
      when(mockDio.post(
        '/auth/register', 
        data: anyNamed('data')
      )).thenAnswer((_) async => Response(
        data: {'message': 'Success'},
        statusCode: 201,
        requestOptions: RequestOptions(path: '/auth/register')
      ));

      // ACT
      await authService.register('User', 'test@test.com', '123456');

      // ASSERT
      verify(mockDio.post('/auth/register', data: {
        "username": "User",
        "email": "test@test.com",
        "password": "123456"
      })).called(1);
    });

    test('getProfile fetches user data', () async {
      // ARRANGE
      final profileData = {'user': {'username': 'Test'}};
      
      when(mockDio.get('/auth/123/profile'))
          .thenAnswer((_) async => Response(
            data: profileData,
            statusCode: 200,
            requestOptions: RequestOptions(path: '/auth/123/profile')
          ));

      // ACT
      final result = await authService.getProfile('123');

      // ASSERT
      expect(result, profileData);
    });

    test('updateUsername sends PUT request', () async {
      // ARRANGE
      when(mockDio.put(
        '/auth/123', 
        data: anyNamed('data')
      )).thenAnswer((_) async => Response(
        data: {'success': true},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/auth/123')
      ));

      // ACT
      await authService.updateUsername('123', 'NewName');

      // ASSERT
      verify(mockDio.put('/auth/123', data: {'username': 'NewName'})).called(1);
    });

    test('logout clears SharedPreferences', () async {
      // ARRANGE
      SharedPreferences.setMockInitialValues({
        'token': 'old_token',
        'userId': 'old_id'
      });

      // ACT
      await authService.logout();

      // ASSERT
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('token'), false);
      expect(prefs.containsKey('userId'), false);
    });

    // NOTE: uploadAvatar is hard to test because mocking 'File' 
    // requires 'dart:io' access which behaves differently in test environments.
    // We usually skip detailed File testing in unit tests or use integration tests.
  });
}