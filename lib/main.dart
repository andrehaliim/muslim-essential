import 'package:firebase_core/firebase_core.dart';
import 'package:shalat_essential/objectbox/location_database.dart';
import 'package:timezone/data/latest.dart' as tzl;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shalat_essential/objectbox.g.dart';
import 'package:shalat_essential/objectbox/store.dart';
import 'package:shalat_essential/services/themedata.dart';
import 'package:shalat_essential/views/newhomepage.dart';
import 'package:workmanager/workmanager.dart';
import 'objectbox/prayer_database.dart';
import 'services/firebase_options.dart';
import 'services/notification_service.dart';

const updateWidgetTask = "updateWidgetTask";
late ObjectBox objectbox;
Admin? objectBoxAdmin;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // 1. Initialize services
    WidgetsFlutterBinding.ensureInitialized();
    await NotificationService.init();
    tzl.initializeTimeZones(); // <-- Initialize timezone database

    // 2. Initialize ObjectBox and get both boxes
    final objectbox = await ObjectBox.create();
    final prayerBox = objectbox.store.box<PrayerDatabase>();
    final locationBox = objectbox.store.box<LocationDatabase>(); // <-- Get the location box

    // 3. Define the task logic
    switch (task) {
      case updateWidgetTask:
        // --- Cancel ALL previously scheduled notifications ---
        // This prevents duplicates and clears out old schedules.
        await NotificationService.cancelAllNotifications();

        // --- Get the Timezone from LocationDatabase ---
        final locationData = locationBox.getAll().firstOrNull;
        if (locationData == null || locationData.timezone.isEmpty) {
          // If we have no location data, we can't schedule accurately.
          // You could optionally schedule a notification to ask the user to open the app.
          objectbox.store.close();
          return Future.value(false); // Indicate failure to schedule
        }
        final tz.Location location = tz.getLocation(locationData.timezone);

        // --- Get today's prayer data ---
        final now = DateTime.now();
        // The date format in your DB is 'dd-MM-yyyy'
        final todayString = DateFormat('dd-MM-yyyy').format(now);
        final query = prayerBox.query(PrayerDatabase_.date.equals(todayString)).build();
        final todayPrayer = query.findFirst();
        query.close();

        if (todayPrayer == null) {
          await NotificationService.showNotification(
            id: 99,
            title: "Prayer Times Update Needed",
            body: "Please open the app to download the new prayer schedule.",
          );
          objectbox.store.close();
          return Future.value(true);
        }

        // --- Schedule notifications for today based on settings ---
        final prayerTimes = {
          1: {'time': tz.TZDateTime.from(todayPrayer.fajr, location), 'enabled': todayPrayer.notifFajr, 'name': 'Fajr'},
          2: {'time': tz.TZDateTime.from(todayPrayer.dhuhr, location), 'enabled': todayPrayer.notifDhuhr, 'name': 'Dhuhr'},
          3: {'time': tz.TZDateTime.from(todayPrayer.asr, location), 'enabled': todayPrayer.notifAsr, 'name': 'Asr'},
          4: {'time': tz.TZDateTime.from(todayPrayer.maghrib, location), 'enabled': todayPrayer.notifMaghrib, 'name': 'Maghrib'},
          5: {'time': tz.TZDateTime.from(todayPrayer.isha, location), 'enabled': todayPrayer.notifIsha, 'name': 'Isha'},
        };

        // Get the current time in the correct timezone for comparison
        final tz.TZDateTime nowInLocation = tz.TZDateTime.now(location);

        for (final entry in prayerTimes.entries) {
          final id = entry.key;
          final time = entry.value['time'] as tz.TZDateTime;
          final enabled = entry.value['enabled'] as bool;
          final name = entry.value['name'] as String;

          if (enabled && time.isAfter(nowInLocation)) {
            await NotificationService.scheduleNotification(
              id: id,
              title: "Prayer Reminder",
              body: "$name prayer is at ${DateFormat.Hm().format(time)}.",
              scheduledTime: time, // Pass the timezone-aware TZDateTime directly
            );
          }
        }

        // Reset checks
        await HomeWidget.saveWidgetData<bool>('fajr_check', todayPrayer.doneFajr);
        await HomeWidget.saveWidgetData<bool>('dhuhr_check', todayPrayer.doneDhuhr);
        await HomeWidget.saveWidgetData<bool>('asr_check', todayPrayer.doneAsr);
        await HomeWidget.saveWidgetData<bool>('maghrib_check', todayPrayer.doneMaghrib);
        await HomeWidget.saveWidgetData<bool>('isha_check', todayPrayer.doneIsha);

        // Save extra info
        await HomeWidget.saveWidgetData<String>('location_name', 'test');
        await HomeWidget.saveWidgetData<String>('date_time', DateFormat('dd MMM yyyy HH:mm').format(DateTime.now()));

        await HomeWidget.updateWidget(name: 'PrayerWidgetProvider');

        objectbox.store.close();
        return Future.value(true);

      default:
        return Future.value(false);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  objectbox = await ObjectBox.create();

  if (kDebugMode && Admin.isAvailable()) {
    // Consider not creating the admin panel on release builds
    objectBoxAdmin = Admin(objectbox.store);
  }

  // Initialize WorkManager
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: kDebugMode, // Set this to true to see logs from the isolate
  );

  // Then init other services for the main app UI
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.init();

  // Schedule the daily task
  await Workmanager().registerPeriodicTask(
    updateWidgetTask, // A unique name for the task
    updateWidgetTask, // The name of the task registered in callbackDispatcher
    frequency: const Duration(hours: 12), // Run every 12-24 hours for reliability
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace, // Replace the old task if it exists
    initialDelay: const Duration(minutes: 5), // Run shortly after app start for the first time
    constraints: Constraints(
      networkType: NetworkType.notRequired,
    ),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    //final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Muslim Essential',
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: NewHomePage(),
    );
  }
}
