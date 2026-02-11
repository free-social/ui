import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' show Color;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Initialize notification service
  static Future<void> initialize() async {
    // Initialize timezone database
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Phnom_Penh'));

    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        print('👆 Notification tapped: ${details.payload}');
      },
    );

    print('✅ Notification service initialized');
    print('🌍 Timezone set to: Asia/Phnom_Penh (Cambodia - UTC+7)');
  }

  // Request notification permissions
  static Future<bool> requestPermissions() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      final exactAlarmGranted = await androidPlugin
          .requestExactAlarmsPermission();
      print('🔔 Notification permission: $granted');
      print('⏰ Exact alarm permission: $exactAlarmGranted');
      return granted ?? false;
    }

    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      print('🔔 Notification permission: $granted');
      return granted ?? false;
    }

    return true;
  }

  // ✅ Schedule daily notification at specific time
  static Future<void> scheduleDailyNotification() async {
    await _notifications.cancelAll();

    final now = tz.TZDateTime.now(tz.local);

    // ⚡ TESTING: 11:50 AM
    // 🔄 PRODUCTION: Change to 23 and 40 for 11:40 PM
    const targetHour = 23;
    const targetMinute = 40;

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      targetHour,
      targetMinute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    print('⏰ Current time: $now');
    print('📅 Scheduled for: $scheduledDate');
    print('⏳ In ${scheduledDate.difference(now).inMinutes} minutes');

    const androidDetails = AndroidNotificationDetails(
      'daily_spending_channel',
      'Daily Spending Notifications',
      channelDescription: 'Daily spending reminder at 11:40 PM',
      importance: Importance.max,
      priority: Priority.max,
      color: Color(0xFF00BFA5),
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF00BFA5),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      0,
      '💰 Daily Spending Reminder',
      'Time to check your spending for today!',
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    print('✅ Notification scheduled for $targetHour:$targetMinute daily');

    // Store scheduled time for in-app check
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notification_hour', targetHour);
    await prefs.setInt('notification_minute', targetMinute);
  }

  // ✅ Check if we should show notification (fallback for OPPO devices)
  static Future<void> checkAndShowIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // Get scheduled time
      final targetHour = prefs.getInt('notification_hour') ?? 23;
      final targetMinute = prefs.getInt('notification_minute') ?? 40;

      // Get last shown date
      final lastShownDate = prefs.getString('last_notification_date');
      final todayString = '${now.year}-${now.month}-${now.day}';

      // Check if current time is past target time
      final currentMinutes = now.hour * 60 + now.minute;
      final targetMinutes = targetHour * 60 + targetMinute;
      final isPastTargetTime = currentMinutes >= targetMinutes;

      // Show if past target time and not shown today
      if (isPastTargetTime && lastShownDate != todayString) {
        print(
          '🔔 Showing fallback notification (OPPO battery optimization workaround)',
        );
        await showTestNotification();
        await prefs.setString('last_notification_date', todayString);
      }
    } catch (e) {
      print('❌ Error in fallback check: $e');
    }
  }

  // Show immediate notification
  static Future<void> showTestNotification() async {
    print('🔔 Showing notification NOW...');

    const androidDetails = AndroidNotificationDetails(
      'daily_spending_channel',
      'Daily Spending Notifications',
      channelDescription: 'Daily spending reminder',
      importance: Importance.max,
      priority: Priority.max,
      color: Color(0xFF00BFA5),
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(
      999,
      '💰 Daily Spending Reminder',
      'Time to check your spending for today!',
      notificationDetails,
    );

    print('✅ Notification shown!');
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    print('🚫 All notifications cancelled');
  }

  // Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final granted = await androidPlugin.areNotificationsEnabled();
      return granted ?? false;
    }

    return true;
  }
}
