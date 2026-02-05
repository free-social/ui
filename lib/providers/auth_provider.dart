import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  // ✅ 1. RESTART LOGIC: Works because AuthService saved the userId
  Future<void> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');

    // Debug prints to verify persistence
    print("--------- CHECK AUTH STATUS ---------");
    print("Token found: ${token != null}");
    print("UserID found: $userId");

    if (token != null && userId != null) {
      _isAuthenticated = true;
      try {
        final responseData = await _authService.getProfile(userId);
        if (responseData.containsKey('user')) {
          _user = User.fromJson(responseData['user']);
        }
      } catch (e) {
        print("Sync failed: $e");
      }
      notifyListeners();
    }
  }

  // --- UPDATE USERNAME ---
  Future<void> updateUsername(String userId, String newUsername) async {
    _setLoading(true);
    try {
      await _authService.updateUsername(userId, newUsername);
      if (_user != null) {
        _user = _user!.copyWith(username: newUsername);
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- UPLOAD AVATAR ---
  Future<void> uploadAvatar(String userId, File imageFile) async {
    _setLoading(true);
    try {
      final response = await _authService.uploadAvatar(userId, imageFile);
      if (response.containsKey('user') &&
          response['user'].containsKey('avatar')) {
        final String newAvatarUrl = response['user']['avatar'];
        if (_user != null) {
          _user = _user!.copyWith(avatar: newAvatarUrl);
        }
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- AUTH METHODS ---

  // ✅ 2. LOGIN LOGIC: Fixed to show Spinner & Fetch Avatar
  Future<void> login(String email, String password) async {
    _setLoading(true); // 👈 Added: Show loading spinner
    try {
      // Step A: Login (Get Token & ID)
      final responseData = await _authService.login(email, password);

      // Step B: Extract ID
      final userId = responseData['user']['id'] ?? responseData['user']['_id'];

      // Step C: 🛡️ SAFETY NET - Fetch full profile immediately
      // This ensures we get the avatar even if the login API forgot to send it.
      if (userId != null) {
        try {
          final profileData = await _authService.getProfile(userId);
          if (profileData.containsKey('user')) {
            _user = User.fromJson(profileData['user']);
          }
        } catch (e) {
          // If profile fetch fails, fall back to basic login data
          print("Profile fetch error during login: $e");
          if (responseData.containsKey('user')) {
            _user = User.fromJson(responseData['user']);
          }
        }
      }

      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false); // 👈 Added: Hide loading spinner
    }
  }

  Future<void> register(String username, String email, String password) async {
    _setLoading(true);
    try {
      await _authService.register(username, email, password);
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> googleLogin() async {
    _setLoading(true);
    try {
      await _authService.googleAuth();

      await checkAuthStatus();

      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
