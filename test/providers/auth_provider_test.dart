import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
// REPLACE with your actual package name
import 'package:spendwise/providers/auth_provider.dart';
import 'package:spendwise/services/auth_service.dart';
// import 'package:spendwise/models/user_model.dart';

// Generate Mock for AuthService
@GenerateMocks([AuthService])
import 'auth_provider_test.mocks.dart';

void main() {
  late AuthProvider authProvider;
  late MockAuthService mockAuthService;

  setUp(() {
    // 1. Reset SharedPreferences before each test
    SharedPreferences.setMockInitialValues({}); 
    
    // 2. Initialize Mock Service
    mockAuthService = MockAuthService();
    
    // 3. Inject Mock into Provider
    authProvider = AuthProvider(authService: mockAuthService);
  });

  group('AuthProvider', () {
    final tUserJson = {
      'id': '123',
      'username': 'TestUser',
      'email': 'test@test.com',
      'avatar': 'avatar.png'
    };

    test('checkAuthStatus finds token and logs user in automatically', () async {
      // ARRANGE: Simulate saved token in SharedPreferences
      SharedPreferences.setMockInitialValues({
        'token': 'fake_token',
        'userId': '123'
      });

      // Mock the profile fetch that happens inside checkAuthStatus
      when(mockAuthService.getProfile('123'))
          .thenAnswer((_) async => {'user': tUserJson});

      // ACT
      await authProvider.checkAuthStatus();

      // ASSERT
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.user?.username, 'TestUser');
    });

    test('checkAuthStatus stays logged out if no token exists', () async {
      // ARRANGE: Empty storage
      SharedPreferences.setMockInitialValues({});

      // ACT
      await authProvider.checkAuthStatus();

      // ASSERT
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.user, null);
    });

    test('login calls service, fetches profile, and updates state', () async {
      // ARRANGE
      // 1. Mock Login call
      when(mockAuthService.login('test@test.com', 'password'))
          .thenAnswer((_) async => {'user': tUserJson, 'token': 'abc'});
      
      // 2. Mock Profile fetch (Your provider calls this for safety)
      when(mockAuthService.getProfile('123'))
          .thenAnswer((_) async => {'user': tUserJson});

      // ACT
      await authProvider.login('test@test.com', 'password');

      // ASSERT
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.user?.email, 'test@test.com');
      expect(authProvider.isLoading, false); // Should turn off loading
      
      verify(mockAuthService.login('test@test.com', 'password')).called(1);
    });

    test('logout clears user and state', () async {
      // ARRANGE: Set initial state to logged in
      SharedPreferences.setMockInitialValues({'token': 'abc'});
      // Mock logout service call
      when(mockAuthService.logout()).thenAnswer((_) async => {});

      // ACT
      await authProvider.logout();

      // ASSERT
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.user, null);
    });
    
    test('updateUsername updates the local user object', () async {
      // ARRANGE: Inject a user first
      // We cheat a bit here by manually setting the user via a login simulation
      // or we can mock the internal state if we exposed a setter (but we didn't).
      // So let's simulate a login first to set the state.
      when(mockAuthService.login(any, any))
          .thenAnswer((_) async => {'user': tUserJson, 'token': 'abc'});
      when(mockAuthService.getProfile(any))
          .thenAnswer((_) async => {'user': tUserJson});
      await authProvider.login('a', 'b');

      // Now test the update
      when(mockAuthService.updateUsername('123', 'NewName'))
          .thenAnswer((_) async => {}); // Returns void or success

      // ACT
      await authProvider.updateUsername('123', 'NewName');

      // ASSERT
      expect(authProvider.user?.username, 'NewName');
    });
  });
}