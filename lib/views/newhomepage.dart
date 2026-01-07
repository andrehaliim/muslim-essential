import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;
import 'package:muslim_essential/components/rotating_dot.dart';
import 'package:muslim_essential/objectbox/location_database.dart';
import 'package:muslim_essential/services/prayer_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:page_transition/page_transition.dart';
import 'package:receive_intent/receive_intent.dart' as receive_intent;
import 'package:timezone/data/latest.dart' as tzl;
import 'package:timezone/timezone.dart' as tz;

import '../components/compass.dart';
import '../components/custom_snackbar.dart';
import '../main.dart';
import '../objectbox.g.dart';
import '../objectbox/prayer_database.dart';
import '../services/colors.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/prayer_tile.dart';
import '../services/widget_update.dart';
import 'history.dart';
import 'login.dart';

class NewHomePage extends StatefulWidget {
  const NewHomePage({super.key});

  @override
  State<NewHomePage> createState() => _NewHomePageState();
}

class _NewHomePageState extends State<NewHomePage> {
  String appVersion = '';
  bool visibleLogout = false;
  String locationName = '';
  late Position position;
  bool isLoading = false;
  late DateTime fajr;
  late DateTime dhuhr;
  late DateTime asr;
  late DateTime maghrib;
  late DateTime isha;
  String nextPrayer = '';
  String nextPrayerTime = '';
  String nickName = 'Guest';
  late Box<PrayerDatabase> prayerBox;
  late Box<LocationDatabase> locationBox;
  User? firebaseUser;
  late PrayerDatabase? todayPrayer;
  late PrayerDatabase? yesterdayPrayer;
  bool isLoadingTracker = false;
  String timezoneName = '';
  StreamSubscription<receive_intent.Intent?>? _intentSub;

  @override
  void initState() {
    initAll();
    _listenForIntents();
    getAppVersion();
    super.initState();
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }


  Future<void> initAll() async {
    showLoading();
    locationBox = objectbox.store.box<LocationDatabase>();
    prayerBox = objectbox.store.box<PrayerDatabase>();

    // 1. User login visibility
    firebaseUser = await FirebaseService.getUserInfo();
    if(firebaseUser != null) {
      visibleLogout = true;
      nickName = await FirebaseService.loadNickname();
    } else {
      visibleLogout = false;
      nickName = 'Guest';
    }

    // 2. Location info and Prayer Data fetching logic
    position = await LocationService().determinePosition();
    locationName = await LocationService().getLocationName(position);
    timezoneName = tzmap.latLngToTimezoneString(position.latitude, position.longitude);
    WidgetUpdate().updateWidgetLocation(location: locationName);

    final lastLocation = locationBox.query().order(LocationDatabase_.id, flags: Order.descending).build().findFirst();
    if(lastLocation == null) {
      LocationDatabase locationDatabase = LocationDatabase(
        name: locationName,
        latitude: position.latitude,
        longitude: position.longitude,
        timezone: timezoneName
      );
      locationBox.put(locationDatabase);
    }

    final firstPrayerRecord = prayerBox.getAll().isNotEmpty ? prayerBox.getAll().first : null;

    bool shouldFetchNewData = false;

    // Condition 1: Prayer DB is empty
    if (firstPrayerRecord == null) {
      shouldFetchNewData = true;
    } else {
      // Condition 2: Location has changed significantly
      if (lastLocation != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lastLocation.latitude,
          lastLocation.longitude,
        );
        if (distanceInMeters > 100) {
          shouldFetchNewData = true;

          LocationDatabase locationDatabase = LocationDatabase(
              name: locationName,
              latitude: position.latitude,
              longitude: position.longitude,
              timezone: timezoneName
          );
          locationBox.put(locationDatabase);
        }
      }

      // Condition 3: Month has changed
      final storedMonth = DateTime.parse(firstPrayerRecord.date).month;
      final currentMonth = DateTime.now().month;
      if (storedMonth != currentMonth) {
        shouldFetchNewData = true;
      }
    }

    if (shouldFetchNewData) {
     // log('=== Fetching new data ===');
      await PrayerService.getmuslimDataForMonth(position, firebaseUser?.uid);
    } else {
     // log('=== No fetching data ===');
    }

    // 3. Read today's record from db
    await calculateTodayPrayer();
    await calculateNextPrayer(DateTime.now());

    // 4. Refresh widget after async tasks finish
    if (mounted) setState(() {});
    showLoading();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    return Scaffold(
      appBar: AppBar(
          title: Row(
            children: [
              Text('Muslim Essential'),
              SizedBox(width: 10,),
              Text('v$appVersion', style: Theme.of(context).textTheme.bodySmall),
              Spacer(),
              Visibility(
                visible: visibleLogout,
                child: GestureDetector(
                  onTap: () => FirebaseService.logout().then((_) async {
                    if (mounted) {
                        await PrayerService().resetDonePrayerDatabase();
                        initAll();
                        CustomSnackbar().successSnackbar(context, 'Logout successful');
                    }
                  }),
                  child: Icon(Icons.logout),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.background, surfaceTintColor: Colors.transparent
      ),
      body: !isLoading
        ? Container(
        padding: EdgeInsets.all(10),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assalamualaikum,', style: Theme.of(context).textTheme.bodyMedium),
              Text(nickName, style: Theme.of(context).textTheme.headlineLarge),
              SizedBox(height: 20,),
              GestureDetector(
                onTap: initAll,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, size: 20,),
                    Expanded(child: Text(locationName, style: Theme.of(context).textTheme.bodyMedium, maxLines: 2,))
                  ],
                ),
              ),
              SizedBox(height: 20,),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Next prayer is,', style: Theme.of(context).textTheme.bodyMedium),
                          Text(nextPrayer, style: Theme.of(context).textTheme.headlineLarge),
                          Text(nextPrayerTime, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: ElevatedButton(
                        style: Theme.of(context).elevatedButtonTheme.style,
                        onPressed: () async {
                          showCompass(context);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.explore, size: 30, color: AppColors.primaryText),
                            SizedBox(height: 5),
                            Text('Qibla', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10,),
              Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(10),
                color: Theme.of(context).colorScheme.surface,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fajr', style: Theme.of(context).textTheme.bodyMedium),
                          Text('Dhuhr', style: Theme.of(context).textTheme.bodyMedium),
                          Text('Asr', style: Theme.of(context).textTheme.bodyMedium),
                          Text('Maghrib', style: Theme.of(context).textTheme.bodyMedium),
                          Text('Isha', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(DateFormat('HH:mm').format(fajr), style: Theme.of(context).textTheme.bodyMedium),
                          Text(DateFormat('HH:mm').format(dhuhr), style: Theme.of(context).textTheme.bodyMedium),
                          Text(DateFormat('HH:mm').format(asr), style: Theme.of(context).textTheme.bodyMedium),
                          Text(DateFormat('HH:mm').format(maghrib), style: Theme.of(context).textTheme.bodyMedium),
                          Text(DateFormat('HH:mm').format(isha), style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          GestureDetector(
                              onTap: () => toggleNotification(1),
                              child: todayPrayer!.notifFajr ? Icon(Icons.notifications_active_outlined, size: 20) : Icon(Icons.notifications_off_outlined, size: 20)),
                          GestureDetector(
                              onTap: () => toggleNotification(2),
                              child: todayPrayer!.notifDhuhr ? Icon(Icons.notifications_active_outlined, size: 20) : Icon(Icons.notifications_off_outlined, size: 20)),
                          GestureDetector(
                              onTap: () => toggleNotification(3),
                              child: todayPrayer!.notifAsr ? Icon(Icons.notifications_active_outlined, size: 20) : Icon(Icons.notifications_off_outlined, size: 20)),
                          GestureDetector(
                              onTap: () => toggleNotification(4),
                              child: todayPrayer!.notifMaghrib ? Icon(Icons.notifications_active_outlined, size: 20) : Icon(Icons.notifications_off_outlined, size: 20)),
                          GestureDetector(
                              onTap: () => toggleNotification(5),
                              child: todayPrayer!.notifIsha ? Icon(Icons.notifications_active_outlined, size: 20) : Icon(Icons.notifications_off_outlined, size: 20)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10,),
              GestureDetector(
                onTap: () async {
                  if (firebaseUser == null) {
                    bool refresh = await Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.rightToLeft,
                        childBuilder: (context) => Login(),
                      ),
                    );
                    if(refresh){
                      initAll();
                    }
                  } else {
                    Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.rightToLeft,
                        childBuilder: (context) => History(),
                      ),
                    );
                  }
                },
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context).colorScheme.surface,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.all(10),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: screenWidth,
                                  height: screenHeight / 25,
                                  child: Text('Yesterday',
                                      style: Theme.of(context).textTheme.headlineMedium,
                                      textAlign: TextAlign.center),
                                ),
                                Text(DateFormat('EEEE').format(DateTime.now().subtract(Duration(days: 1))), style: Theme.of(context).textTheme.bodyMedium),
                                Text(DateFormat("dd MMMM yyyy").format(DateTime.now().subtract(Duration(days: 1))),style: Theme.of(context).textTheme.bodyMedium),
                                const SizedBox(height: 10),
                                PrayerTile(prayerDatabase: yesterdayPrayer),
                              ],
                            ),
                          ),
                          const VerticalDivider(
                            thickness: 2,
                            width: 40,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: screenWidth,
                                  height: screenHeight / 25,
                                  child: Text('Today',
                                      style: Theme.of(context).textTheme.headlineMedium,
                                      textAlign: TextAlign.center),
                                ),
                                Text(DateFormat('EEEE').format(DateTime.now()), style: Theme.of(context).textTheme.bodyMedium),
                                Text(DateFormat("dd MMMM yyyy").format(DateTime.now()),style: Theme.of(context).textTheme.bodyMedium),
                                const SizedBox(height: 10),
                                PrayerTile(prayerDatabase: todayPrayer),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10,),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      width: screenWidth,
                      height: kMinInteractiveDimension,
                      child: ElevatedButton(
                        style: Theme.of(context).elevatedButtonTheme.style,
                        onPressed: trackPrayerFunction,
                        child: isLoadingTracker
                            ? RotatingDot(scale: 20)
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_box_outlined, size: 30, color: AppColors.primaryText,),
                            Text('Track Prayer', style: Theme.of(context).primaryTextTheme.labelLarge),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      )
          : Center(child: RotatingDot(scale: 50))
    );
  }

  void toggleNotification(int id) async {
    String prayerName = '';
    DateTime time;
    bool isNotificationEnabled = false;

    switch (id) {
      case 1:
        prayerName = "Fajr";
        time = fajr;
        isNotificationEnabled = !todayPrayer!.notifFajr;
        break;
      case 2:
        prayerName = "Dhuhr";
        time = dhuhr;
        isNotificationEnabled = !todayPrayer!.notifDhuhr;
       // log(isNotificationEnabled.toString());
        break;
      case 3:
        prayerName = "Asr";
        time = asr;
        isNotificationEnabled = !todayPrayer!.notifAsr;
        break;
      case 4:
        prayerName = "Maghrib";
        time = maghrib;
        isNotificationEnabled = !todayPrayer!.notifMaghrib;
        break;
      case 5:
        prayerName = "Isha";
        time = isha;
        isNotificationEnabled = !todayPrayer!.notifIsha;
        break;
      default:
        return;
    }

    setState(() {
      final allPrayers = prayerBox.getAll();
      List<PrayerDatabase> updatedPrayers = [];

      for (var prayer in allPrayers) {
        switch (id) {
          case 1:
            prayer.notifFajr = isNotificationEnabled;
            break;
          case 2:
            prayer.notifDhuhr = isNotificationEnabled;
            break;
          case 3:
            prayer.notifAsr = isNotificationEnabled;
            break;
          case 4:
            prayer.notifMaghrib = isNotificationEnabled;
            break;
          case 5:
            prayer.notifIsha = isNotificationEnabled;
            break;
          default:
            return;
        }
        updatedPrayers.add(prayer);
      }

        prayerBox.putMany(updatedPrayers);
        calculateTodayPrayer();
    });

    if (isNotificationEnabled) {
        NotificationService.scheduleNotification(
          id: id,
          title: "Prayer Reminder",
          body: "$prayerName prayer is at ${DateFormat.Hm().format(time)}.",
          scheduledTime: time,
        );
      CustomSnackbar().successSnackbar(context, "Notification for $prayerName is enabled");
      WidgetUpdate().updateWidgetPrayerNotification(name: prayerName, notification: true);
    } else {
      // Cancel notification
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.cancel(id);
      CustomSnackbar().failedSnackbar(context, "Notification for $prayerName is disabled");
      WidgetUpdate().updateWidgetPrayerNotification(name: prayerName, notification: false);
    }
  }

  void trackPrayerFunction() async {
    if (firebaseUser == null) {
      bool refresh = await Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.rightToLeft,
          childBuilder: (context) => Login(),
        ),
      );
      if(refresh){
        initAll();
        await PrayerService().trackPrayer(context, firebaseUser!.uid);
        await FirebaseService().getFirebasePrayers();
        await calculateTodayPrayer();
      }
    } else {
      setState(() {
        isLoadingTracker = true;
      });
      await PrayerService().trackPrayer(context, firebaseUser!.uid);
      await FirebaseService().getFirebasePrayers();
      await calculateTodayPrayer();
      setState(() {
        isLoadingTracker = false;
      });
    }
  }

  Future<void> calculateTodayPrayer() async {
    tzl.initializeTimeZones();
    double latitude = position.latitude;
    double longitude = position.longitude;
    DateTime today = DateTime.now();
    DateTime yesterday = DateTime.now().subtract(Duration(days: 1));

    final String todayDate = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final String yesterdayDate = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

    todayPrayer = prayerBox.query(PrayerDatabase_.date.equals(todayDate)).build().findFirst();
    yesterdayPrayer = prayerBox.query(PrayerDatabase_.date.equals(yesterdayDate)).build().findFirst();

    if (todayPrayer != null) {
      final location = tz.getLocation(tzmap.latLngToTimezoneString(latitude, longitude));

      fajr     = tz.TZDateTime.from(todayPrayer!.fajr, location);
      dhuhr    = tz.TZDateTime.from(todayPrayer!.dhuhr, location);
      asr      = tz.TZDateTime.from(todayPrayer!.asr, location);
      maghrib  = tz.TZDateTime.from(todayPrayer!.maghrib, location);
      isha     = tz.TZDateTime.from(todayPrayer!.isha, location);

      WidgetUpdate().updateWidgetPrayerTime(prayerDatabase: todayPrayer!);
      WidgetUpdate().updateWidgetPrayerTracker(prayerDatabase: todayPrayer!);
    }
  }

  Future<void> calculateNextPrayer(DateTime now) async{
    // Create ordered list of today's prayer times
    final List<Map<String, dynamic>> prayersToday = [
      {"name": "Fajr", "time": fajr},
      {"name": "Dhuhr", "time": dhuhr},
      {"name": "Asr", "time": asr},
      {"name": "Maghrib", "time": maghrib},
      {"name": "Isha", "time": isha},
    ];

    // Find the first prayer time that is after current time
    Map<String, dynamic>? next;
    for (var p in prayersToday) {
      if (now.isBefore(p["time"])) {
        next = p;
        break;
      }
    }

    // If none remaining today -> next is tomorrow's Fajr
    if (next == null) {
      final tomorrowPrayer = objectbox.store.box<PrayerDatabase>()
          .query(PrayerDatabase_.date.equals(DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)))))
          .build()
          .findFirst();

      next = {
        "name": "Fajr",
        "time": tomorrowPrayer!.fajr.add(const Duration(days: 1))
      };
    }

    // Calculate remaining duration
    Duration remaining = next["time"].difference(now);
    String hours = remaining.inHours.toString().padLeft(2, '0');
    String minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');

    setState(() {
      nextPrayer = next!["name"];
      nextPrayerTime = "in ${hours}h ${minutes}m";
    });
  }

  Future<void> getAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      appVersion = info.version;
    });
  }

  void showLoading() {
    setState(() {
      isLoading = !isLoading;
    });
  }

  void _listenForIntents() async {
    final initialIntent = await receive_intent.ReceiveIntent.getInitialIntent();
    if (initialIntent?.extra?['fromWidget'] == 'qibla') {
      showCompass(context);
    } else if (initialIntent?.extra?['fromWidget'] == 'tracker'){
      trackPrayerFunction();
    }

    _intentSub = receive_intent.ReceiveIntent.receivedIntentStream.listen((intent) {
      if (intent!.extra?['fromWidget'] == 'qibla') {
        showCompass(context);
      } else if (intent.extra?['fromWidget'] == 'tracker') {
        trackPrayerFunction();
      }
    });
  }
}
