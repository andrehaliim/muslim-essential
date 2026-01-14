import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:muslim_essential/components/themedata.dart';
import 'package:muslim_essential/objectbox.g.dart';
import 'package:muslim_essential/objectbox/store.dart';
import 'package:muslim_essential/views/forgot_password.dart';
import 'package:muslim_essential/views/history.dart';
import 'package:muslim_essential/views/login.dart';
import 'package:muslim_essential/views/register.dart';
import 'package:timezone/data/latest.dart' as tzl;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import 'firebase_options.dart';
import 'objectbox/location_database.dart';
import 'objectbox/prayer_database.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'views/homepage.dart';

const String updateWidgetTask = 'updateWidgetTask';

late ObjectBox objectbox;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    ObjectBox? bgObjectBox;

    try {
      // 🌍 Timezone
      tzl.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

      // 🔥 Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 📦 ObjectBox (background isolate)
      bgObjectBox = await ObjectBox.open();
      final prayerBox = bgObjectBox.store.box<PrayerDatabase>();
      final locationBox = bgObjectBox.store.box<LocationDatabase>();

      final now = DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(now);

      final todayPrayer = prayerBox
          .query(PrayerDatabase_.date.equals(todayKey))
          .build()
          .findFirst();

      final lastLocation = locationBox
          .query()
          .order(LocationDatabase_.id, flags: Order.descending)
          .build()
          .findFirst();

      if (task == updateWidgetTask) {
        // 🔔 Notifications
        if (todayPrayer != null) {
          await NotificationService().cancelAllNotifications();
          await NotificationService().scheduleAllNotification(todayPrayer);
        }

        // ♻ Reset prayer tracking
        await HomeWidget.saveWidgetData('fajr_check', false);
        await HomeWidget.saveWidgetData('dhuhr_check', false);
        await HomeWidget.saveWidgetData('asr_check', false);
        await HomeWidget.saveWidgetData('maghrib_check', false);
        await HomeWidget.saveWidgetData('isha_check', false);

        // 📱 Widget data
        await HomeWidget.saveWidgetData(
          'location_name',
          lastLocation?.name ?? 'Unknown location',
        );

        await HomeWidget.saveWidgetData(
          'date_time',
          DateFormat('dd MMMM yyyy').format(now),
        );

        await HomeWidget.updateWidget(name: 'PrayerWidgetProvider');
        return true;
      }

      return false;
    } catch (e) {
      // 🛑 Fail-safe
      try {
        await NotificationService.showNotification(
          id: 99,
          title: 'Background Error',
          body: e.toString(),
        );
      } catch (_) {}

      return false;
    } finally {
      // 🔒 ALWAYS close store
      bgObjectBox?.store.close();
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🌍 Timezone (UI isolate)
  tzl.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

  // 📍 Location permission
  await LocationService().locationPermission();

  // 🔔 Notifications
  await NotificationService.init();

  // 🔥 Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 📦 ObjectBox (UI isolate)
  objectbox = await ObjectBox.open();

  // 🛠 Admin (debug only)
  if (kDebugMode && Admin.isAvailable()) {
    Admin(objectbox.store);
  }

  // ⏰ Schedule daily background task
  await _scheduleDailyWidgetUpdate();

  runApp(const MyApp());
}

Future<void> _scheduleDailyWidgetUpdate() async {
  final now = DateTime.now();

  // Run after midnight (01:00 for safety)
  final nextRun = DateTime(now.year, now.month, now.day + 1, 1);
  final initialDelay = nextRun.difference(now);

  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: kDebugMode,
  );

  await Workmanager().registerPeriodicTask(
    updateWidgetTask,
    updateWidgetTask,
    frequency: const Duration(hours: 24),
    initialDelay: initialDelay,
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 10),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muslim Essential',
      darkTheme: appDarkTheme,
      themeMode: ThemeMode.dark,
      initialRoute: '/',
      routes: {
        '/': (context) => const Homepage(),
        '/login': (context) => const Login(),
        '/history': (context) => const History(),
        '/register': (context) => const Register(),
        '/forgot': (context) => const ForgotPassword(),
      },
    );
  }
}
