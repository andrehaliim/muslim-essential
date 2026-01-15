import 'dart:developer';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

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

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime? scheduledTime,
  }) async {
    if (scheduledTime == null) return;

    final tzScheduled =
    tz.TZDateTime.from(scheduledTime, tz.local)
        .subtract(const Duration(minutes: 5));

    if (tzScheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      log("⏭️ Notification skipped (time already passed): $tzScheduled");
      return;
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
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }


  static Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future <void> schedulePrayerNotif({required String name, required String id, required DateTime time, required bool isEnabled}) async {
    final ymd = DateFormat('yyyyMMdd').format(time);
    final notificationId = int.parse('$ymd$id');

    if(isEnabled) {
      NotificationService.scheduleNotification(
        id: notificationId,
        title: "Prayer Reminder",
        body: "$name prayer is at ${DateFormat.Hm().format(time)}.",
        scheduledTime: time,
      );
      log("🔔 Notification is set for ${DateFormat('yyyy-MM-dd').format(time)} at $time with id : $notificationId 🔔");
    }
  }
}
