import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/providers/theme_provider.dart';

void main() {
  late ThemeProvider themeProvider;

  setUp(() {
    // Reset SharedPreferences before every test
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeProvider', () {
    test(
      'initial state defaults to light mode when no saved preference',
      () async {
        themeProvider = ThemeProvider();

        // Wait for async _loadTheme to complete
        await Future.delayed(const Duration(milliseconds: 100));

        expect(themeProvider.themeMode, ThemeMode.light);
        expect(themeProvider.isDarkMode, false);
      },
    );

    test('loads saved light mode preference from SharedPreferences', () async {
      // Arrange: Set saved preference to light mode
      SharedPreferences.setMockInitialValues({'isDarkMode': false});

      // Act
      themeProvider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(themeProvider.themeMode, ThemeMode.light);
      expect(themeProvider.isDarkMode, false);
    });

    test('loads saved dark mode preference from SharedPreferences', () async {
      // Arrange: Set saved preference to dark mode
      SharedPreferences.setMockInitialValues({'isDarkMode': true});

      // Act
      themeProvider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(themeProvider.isDarkMode, true);
    });

    test('toggleTheme changes from dark to light', () async {
      SharedPreferences.setMockInitialValues({'isDarkMode': true});
      themeProvider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      // Initially dark
      expect(themeProvider.isDarkMode, true);

      // Toggle to light
      themeProvider.toggleTheme(false);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(themeProvider.themeMode, ThemeMode.light);
      expect(themeProvider.isDarkMode, false);
    });

    test('toggleTheme changes from light to dark', () async {
      SharedPreferences.setMockInitialValues({'isDarkMode': false});
      themeProvider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      // Initially light
      expect(themeProvider.isDarkMode, false);

      // Toggle to dark
      themeProvider.toggleTheme(true);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(themeProvider.isDarkMode, true);
    });

    test('toggleTheme saves preference to SharedPreferences', () async {
      themeProvider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      // Toggle to light mode
      themeProvider.toggleTheme(false);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify it was saved
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isDarkMode'), false);
    });

    test('toggleTheme notifies listeners', () async {
      themeProvider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      bool notified = false;
      themeProvider.addListener(() {
        notified = true;
      });

      // Toggle theme
      themeProvider.toggleTheme(false);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notified, true);
    });

    test('multiple toggles work correctly', () async {
      themeProvider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      // Toggle to light
      themeProvider.toggleTheme(false);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(themeProvider.isDarkMode, false);

      // Toggle back to dark
      themeProvider.toggleTheme(true);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(themeProvider.isDarkMode, true);

      // Toggle to light again
      themeProvider.toggleTheme(false);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(themeProvider.isDarkMode, false);

      // Verify last preference is persisted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isDarkMode'), false);
    });
  });
}
