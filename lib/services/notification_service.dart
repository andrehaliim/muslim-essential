import 'dart:developer';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('ic_stat_prayer');
    const initSettings = InitializationSettings(android: androidInit);

    await _notifications.initialize(initSettings);

    await requestPermissions();
  }

  static Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidImplementation =
      _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      final iosImplementation =
      _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await iosImplementation?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static Future<void> showNotification({required int id, required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'main_channel',
      'Main Channel',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notifications.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> scheduleNotification({required int id, required String title, required String body, required DateTime? scheduledTime}) async {
    if(scheduledTime != null){
      var tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local).subtract(const Duration(minutes: 5));

      if (tzScheduled.isBefore(tz.TZDateTime.now(tz.local))) {
        tzScheduled = tzScheduled.add(const Duration(days: 1));
      }

      await _notifications.zonedSchedule(
          id,
          title,
          body,
          tzScheduled,
          const NotificationDetails(
              android: AndroidNotificationDetails(
                  'your channel id',
                  'your channel name',
                  channelDescription: 'your channel description',
                  importance: Importance.max,
                  priority: Priority.high,
                  playSound: true,
                  enableVibration: true,
                  icon: 'ic_stat_prayer',
              )),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);

      logNotification(scheduledTime, id, null);
    }
  }

  static Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }

  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  static void logNotification(DateTime dateTime, int id, bool? isInit) {
    final dateStr = DateFormat('yyyy-MM-dd').format(dateTime);
    final timeStr = DateFormat('HH:mm:ss').format(dateTime);
    log("🔔 Notification scheduled for $dateStr at $timeStr (ID: $id) is init : $isInit");
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    log("All scheduled notifications have been cancelled.");
  }
}
