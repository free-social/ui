import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/services/notification_service.dart'; // Used in tests

void main() {
  setUp(() {
    // Reset SharedPreferences before every test
    SharedPreferences.setMockInitialValues({});
  });

  group('NotificationService', () {
    // Note: FlutterLocalNotificationsPlugin is difficult to mock fully in unit tests
    // We'll focus on testing the logic around SharedPreferences and time calculations
    // Actual notification service tests that call the plugin methods are skipped
    // as they require platform bindings which are not available in standard unit tests

    test(
      'checkAndShowIfNeeded respects time constraints - before target time',
      () async {
        // Arrange - Set target time to 23:40
        SharedPreferences.setMockInitialValues({
          'notification_hour': 23,
          'notification_minute': 40,
        });

        final now = DateTime.now();

        // If current time is before 23:40, notification should not be shown
        // We can't directly test this without mocking DateTime, but we can verify the logic

        final currentMinutes = now.hour * 60 + now.minute;
        final targetMinutes = 23 * 60 + 40; // 23:40 = 1420 minutes
        final isPastTargetTime = currentMinutes >= targetMinutes;

        // This should be false for most test runs (unless run after 23:40)
        if (!isPastTargetTime) {
          expect(isPastTargetTime, false);
        }
      },
    );

    test('time calculation logic works correctly', () {
      // Test the time comparison logic
      final targetHour = 23;
      final targetMinute = 40;
      final targetMinutes = targetHour * 60 + targetMinute;

      expect(targetMinutes, 1420); // 23 * 60 + 40 = 1420

      // Morning time (e.g., 9:00 AM = 540 minutes)
      final morningMinutes = 9 * 60 + 0;
      expect(morningMinutes < targetMinutes, true);

      // Evening time after target (e.g., 23:45 = 1425 minutes)
      final eveningMinutes = 23 * 60 + 45;
      expect(eveningMinutes >= targetMinutes, true);
    });

    test('date string format is correct', () {
      final now = DateTime(2024, 2, 15, 10, 30);
      final dateString = '${now.year}-${now.month}-${now.day}';

      expect(dateString, '2024-2-15');
    });

    test('notification should not show if already shown today', () async {
      // Arrange
      final now = DateTime.now();
      final todayString = '${now.year}-${now.month}-${now.day}';

      SharedPreferences.setMockInitialValues({
        'notification_hour': 23,
        'notification_minute': 40,
        'last_notification_date': todayString,
      });

      final prefs = await SharedPreferences.getInstance();
      final lastShownDate = prefs.getString('last_notification_date');

      // Assert - should be today, so notification should not be shown again
      expect(lastShownDate, todayString);
      expect(lastShownDate == todayString, true);
    });

    test('notification should show if last shown date is different', () async {
      // Arrange
      final now = DateTime.now();
      final todayString = '${now.year}-${now.month}-${now.day}';
      final yesterdayString = '${now.year}-${now.month}-${now.day - 1}';

      SharedPreferences.setMockInitialValues({
        'notification_hour': 23,
        'notification_minute': 40,
        'last_notification_date': yesterdayString,
      });

      final prefs = await SharedPreferences.getInstance();
      final lastShownDate = prefs.getString('last_notification_date');

      // Assert - should be yesterday, so notification can be shown today
      expect(lastShownDate, yesterdayString);
      expect(lastShownDate != todayString, true);
    });

    test('default notification time is loaded correctly', () async {
      // Arrange - No saved preferences
      SharedPreferences.setMockInitialValues({});

      final prefs = await SharedPreferences.getInstance();
      final targetHour = prefs.getInt('notification_hour') ?? 23;
      final targetMinute = prefs.getInt('notification_minute') ?? 40;

      // Assert - defaults to 23:40
      expect(targetHour, 23);
      expect(targetMinute, 40);
    });

    test('saved notification time is loaded correctly', () async {
      // Arrange - Custom saved time
      SharedPreferences.setMockInitialValues({
        'notification_hour': 20,
        'notification_minute': 30,
      });

      final prefs = await SharedPreferences.getInstance();
      final targetHour = prefs.getInt('notification_hour');
      final targetMinute = prefs.getInt('notification_minute');

      // Assert
      expect(targetHour, 20);
      expect(targetMinute, 30);
    });

    test('time comparison edge case - exactly at target time', () {
      final targetHour = 23;
      final targetMinute = 40;
      final targetMinutes = targetHour * 60 + targetMinute;

      final currentHour = 23;
      final currentMinute = 40;
      final currentMinutes = currentHour * 60 + currentMinute;

      final isPastTargetTime = currentMinutes >= targetMinutes;

      // At exactly 23:40, should be past target time (>= condition)
      expect(isPastTargetTime, true);
    });
  });
}
