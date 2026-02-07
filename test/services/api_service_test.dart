import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
// REPLACE with your actual package name
import 'package:spendwise/services/api_service.dart';

// ✅ Generate a Mock for HttpClientAdapter
@GenerateMocks([HttpClientAdapter])
import 'api_service_test.mocks.dart';

void main() {
  late ApiService apiService;
  late MockHttpClientAdapter mockAdapter;

  setUp(() {
    // 1. Initialize Service
    apiService = ApiService();
    
    // 2. Create Mock Adapter
    mockAdapter = MockHttpClientAdapter();

    // 3. Replace the real network adapter with our mock
    // This stops Dio from trying to go to the internet
    apiService.client.httpClientAdapter = mockAdapter;
  });

  group('ApiService Interceptors', () {
    
    test('Request should contain "Authorization" header when token exists', () async {
      // ARRANGE
      // 1. Simulate a saved token
      SharedPreferences.setMockInitialValues({'token': 'test_token_123'});

      // 2. Setup the mock adapter to return a success 200 OK
      // We capture the 'options' here to check them later
      RequestOptions? capturedOptions;
      
      when(mockAdapter.fetch(any, any, any))
          .thenAnswer((invocation) async {
            // Capture the request options to inspect headers
            capturedOptions = invocation.positionalArguments[0] as RequestOptions;
            
            return ResponseBody.fromString(
              '{"success": true}', 
              200,
              headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
            );
          });

      // ACT
      // Make a dummy request (path doesn't matter)
      await apiService.client.get('/test-endpoint');

      // ASSERT
      // Check if the interceptor added the header
      expect(capturedOptions, isNotNull);
      expect(capturedOptions?.headers['Authorization'], 'Bearer test_token_123');
    });

    test('Request should NOT contain "Authorization" header when token is missing', () async {
      // ARRANGE
      // 1. Simulate empty storage
      SharedPreferences.setMockInitialValues({});

      RequestOptions? capturedOptions;

      when(mockAdapter.fetch(any, any, any))
          .thenAnswer((invocation) async {
            capturedOptions = invocation.positionalArguments[0] as RequestOptions;
            return ResponseBody.fromString('{}', 200);
          });

      // ACT
      await apiService.client.get('/test-endpoint');

      // ASSERT
      expect(capturedOptions, isNotNull);
      expect(capturedOptions?.headers['Authorization'], null);
    });
  });
}