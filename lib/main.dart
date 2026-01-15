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
import 'package:workmanager/workmanager.dart';

import 'firebase_options.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'views/homepage.dart';

const String updateWidgetTask = 'updateWidgetTask';

late ObjectBox objectbox;
Admin? objectBoxAdmin;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      if (task != updateWidgetTask) return false;

      final now = DateTime.now();
      final ymd = DateFormat('yyyyMMdd').format(now);

      await HomeWidget.saveWidgetData(
        'fajr_time',
        await HomeWidget.getWidgetData<String>('${ymd}_0_Fajr', defaultValue: '--:--'),
      );
      await HomeWidget.saveWidgetData(
        'dhuhr_time',
        await HomeWidget.getWidgetData<String>('${ymd}_1_Dhuhr', defaultValue: '--:--'),
      );
      await HomeWidget.saveWidgetData(
        'asr_time',
        await HomeWidget.getWidgetData<String>('${ymd}_2_Asr', defaultValue: '--:--'),
      );
      await HomeWidget.saveWidgetData(
        'maghrib_time',
        await HomeWidget.getWidgetData<String>('${ymd}_3_Maghrib', defaultValue: '--:--'),
      );
      await HomeWidget.saveWidgetData(
        'isha_time',
        await HomeWidget.getWidgetData<String>('${ymd}_4_Isha', defaultValue: '--:--'),
      );

      await HomeWidget.saveWidgetData('fajr_check', false);
      await HomeWidget.saveWidgetData('dhuhr_check', false);
      await HomeWidget.saveWidgetData('asr_check', false);
      await HomeWidget.saveWidgetData('maghrib_check', false);
      await HomeWidget.saveWidgetData('isha_check', false);

      await HomeWidget.saveWidgetData(
        'date_time',
        DateFormat('dd MMMM yyyy').format(now),
      );

      await HomeWidget.updateWidget(name: 'PrayerWidgetProvider');
      return true;
    } catch (e) {
      await HomeWidget.saveWidgetData(
        'location_name',
        e,
      );
      await HomeWidget.updateWidget(name: 'PrayerWidgetProvider');
      return false;
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocationService().locationPermission();
  await NotificationService.init();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  objectbox = await ObjectBox.open();
  objectBoxAdmin = kDebugMode && Admin.isAvailable() ? Admin(objectbox.store) : null;

  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  final updateWidgetDelay = tomorrow.difference(now);

  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'dailyWidgetUpdate',
    updateWidgetTask,
    frequency: const Duration(hours: 24),
    initialDelay: updateWidgetDelay,
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
  );

  runApp(
    const MyApp(),
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
