import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' show Color;
import 'expense_service.dart';

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
        // print('👆 Notification tapped: ${details.payload}');
      },
    );

    // print('✅ Notification service initialized');
    // print('🌍 Timezone set to: Asia/Phnom_Penh (Cambodia - UTC+7)');
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
      // print('🔔 Notification permission: $granted');
      return granted ?? false;
    }

    return true;
  }

  // ✅ Schedule daily notification with dynamic content
  static Future<void> scheduleDailyNotification() async {
    try {
      await _notifications.cancelAll();
    } catch (e) {
      // Ignore cancelAll errors on some Android devices
    }

    final now = tz.TZDateTime.now(tz.local);

    // 🔄 PRODUCTION: 11:40 PM daily notification
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

    String body = 'Time to check your spending for today!';

    // Logic: If schedule is for TODAY, we can fetch the current total.
    // If it's already past 11:40 PM, we schedule for tomorrow, so we use generic message.
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
      // Generic message for tomorrow since we don't know the future
      body = 'Time to check your spending for today!';
    } else {
      // It's for later today, so fetch the current total!
      try {
        final expenseService = ExpenseService(); // Create instance
        final total = await expenseService.getDailyTotal();
        // Format: $50.00
        final formattedTotal = total.toStringAsFixed(2);
        body = 'Your total spending today is \$$formattedTotal';
      } catch (e) {
        // print('Error fetching total for notification: $e');
        // Fallback to generic
        body = 'Time to check your spending for today!';
      }
    }

    // print('⏰ Current time: $now');
    // print('📅 Scheduled for: $scheduledDate');
    // print('📝 Body: $body');
    // print('⏳ In ${scheduledDate.difference(now).inMinutes} minutes');

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
      styleInformation: BigTextStyleInformation(''), // Allows long text
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
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // print('✅ Notification scheduled for $targetHour:$targetMinute daily');

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

      // print('🔍 FALLBACK CHECK:');
      // print(
      //   '   Current time: ${now.hour}:${now.minute} (${currentMinutes} min)',
      // );
      // print('   Target time: $targetHour:$targetMinute (${targetMinutes} min)');
      // print('   Is past target: $isPastTargetTime');
      // print('   Last shown: $lastShownDate');
      // print('   Today: $todayString');

      // Show if past target time and not shown today
      if (isPastTargetTime && lastShownDate != todayString) {
        // print('✅ TRIGGERING FALLBACK NOTIFICATION');

        // Fetch daily total
        String body = 'Time to check your spending for today!';
        try {
          final expenseService = ExpenseService();
          final total = await expenseService.getDailyTotal();
          final formattedTotal = total.toStringAsFixed(2);
          body = 'Your total spending today is \$$formattedTotal';
        } catch (e) {
          print('Error fetching total for fallback: $e');
        }

        // Show notification with daily total
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
          styleInformation: BigTextStyleInformation(''),
        );

        const notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: DarwinNotificationDetails(),
        );

        await _notifications.show(
          999,
          '💰 Daily Spending Reminder',
          body,
          notificationDetails,
        );

        await prefs.setString('last_notification_date', todayString);
        // print('✅ Fallback notification shown!');
      } else {
        // print(
        //   '⏭️  Fallback not needed (already shown or not past target time)',
        // );
      }
    } catch (e) {
      // print('❌ Error in fallback check: $e');
    }
  }

  // Show immediate notification with daily total
  static Future<void> showTestNotification() async {
    // print('🔔 Showing notification NOW...');

    // Fetch daily total
    String body = 'Time to check your spending for today!';
    try {
      final expenseService = ExpenseService();
      final total = await expenseService.getDailyTotal();
      final formattedTotal = total.toStringAsFixed(2);
      body = 'Your total spending today is \$$formattedTotal';
    } catch (e) {
      // print('Error fetching total: $e');
    }

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
      styleInformation: BigTextStyleInformation(''),
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(
      999,
      '💰 Daily Spending Reminder',
      body,
      notificationDetails,
    );

    print('✅ Notification shown!');
  }

  // Schedule a test notification for 1 minute from now
  static Future<void> scheduleTestNotificationIn1Minute() async {
    try {
      await _notifications.cancelAll();
    } catch (e) {
      // Ignore cancelAll errors on some Android devices
    }

    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = now.add(const Duration(minutes: 1));

    // Fetch daily total
    String body = 'Time to check your spending for today!';
    try {
      final expenseService = ExpenseService();
      final total = await expenseService.getDailyTotal();
      final formattedTotal = total.toStringAsFixed(2);
      body = 'Your total spending today is \$$formattedTotal';
    } catch (e) {
      print('Error fetching total: $e');
    }

    // print('==========================================');
    // print('🔔 SCHEDULING TEST NOTIFICATION');
    // print('⏰ Current time: $now');
    // print('📅 Scheduled for: $scheduledDate');
    // print('📝 Body: $body');
    // print('⏳ Will fire in: ${scheduledDate.difference(now).inSeconds} seconds');
    // print('==========================================');

    const androidDetails = AndroidNotificationDetails(
      'daily_spending_channel',
      'Daily Spending Notifications',
      channelDescription: 'Daily spending reminder test',
      importance: Importance.max,
      priority: Priority.max,
      color: Color(0xFF00BFA5),
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF00BFA5),
      ledOnMs: 1000,
      ledOffMs: 500,
      styleInformation: BigTextStyleInformation(''),
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
      '💰 Daily Spending Reminder (TEST)',
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    // Verify it was scheduled
    final pending = await _notifications.pendingNotificationRequests();
    print('✅ Notification scheduled!');
    print('📋 Pending notifications count: ${pending.length}');
    for (var p in pending) {
      print('   - ID: ${p.id}, Title: ${p.title}, Body: ${p.body}');
    }
    print('==========================================');
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      print('🚫 All notifications cancelled');
    } catch (e) {
      print('⚠️  Could not cancel notifications: $e');
    }
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
