/*import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:page_transition/page_transition.dart';
import 'package:receive_intent/receive_intent.dart' as receive_intent;
import 'package:shalat_essential/components/compass.dart';
import 'package:shalat_essential/components/rotating_dot.dart';
import 'package:shalat_essential/services/colors.dart';
import 'package:shalat_essential/services/firebase_service.dart';
import 'package:shalat_essential/services/location_service.dart';
import 'package:shalat_essential/services/notification_service.dart';
import 'package:shalat_essential/services/prayer_service.dart';
import 'package:shalat_essential/services/prayer_tile.dart';
import 'package:shalat_essential/services/widget_update.dart';
import 'package:shalat_essential/views/history.dart';
import 'package:shalat_essential/views/login.dart';
import 'package:timezone/timezone.dart' as tz;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isGetLocation = false;
  late Future<void> initFuture;
  String locationName = '';
  DateTime? _lastTime;
  Timer? _timer;
  String nextPrayer = '';
  String nextPrayerTime = '';
  String? nickname;
  bool isLoadingTracker = false;
  PrayerModel? todayPrayer;
  PrayerModel? yesterdayPrayer;
  DateTime todayDate = DateTime.now();
  DateTime yesterdayDate = DateTime.now().subtract(const Duration(days: 1));
  PrayerModel prayerModel = PrayerModel.empty(null);
  StreamSubscription<receive_intent.Intent?>? _intentSub;
  String appVersion = '';
  bool visibleLogout = false;

  @override
  void initState() {
    super.initState();
    getAppVersion();
    initFuture = initAll();
    _lastTime = DateTime.now();
    _timer = Timer.periodic(Duration(seconds: 10), (timer) {
      DateTime now = DateTime.now();

      if (_lastTime?.minute != now.minute) {
        initAll();
        _lastTime = now;
      }
    });
    loadPrefs();
    _listenForIntents();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _intentSub?.cancel();
    super.dispose();
  }

  Future<void> initAll() async {
    User? user = await FirebaseService.getUserInfo();
    if(user != null){
      visibleLogout = true;
    }

    setState(() {
      isGetLocation = true;
    });
    final position = await LocationService().determinePosition();
    LocationService().getLocationName(position).then((value) {
      setState(() {
        locationName = value;
        WidgetUpdate().updateWidgetLocation(location: value);
      });
    });
    PrayerService.getShalatData(position).then((value) {
        setState(() {
          setPrayerData(value);
        });
    });
    if(user != null) {
      FirebaseService.loadNickname().then((value) {
        if (value != null) {
          setState(() {
            nickname = value;
          });
        }
      });
      PrayerService().getTracker(user.uid).then((value) {
        setState(() {
          todayPrayer = value['today'];
          yesterdayPrayer = value['yesterday'];
          WidgetUpdate().updateWidgetPrayerTracker(
            prayerModel: todayPrayer,
          );
        });
      });
    }
    setState(() {
      isGetLocation = false;
    });
  }

  Future<void> getAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      appVersion = info.version;
    });
  }

  void _listenForIntents() async {
    final initialIntent = await receive_intent.ReceiveIntent.getInitialIntent();
    if (initialIntent?.extra?['fromWidget'] == 'qibla') {
      showCompass();
    } else if (initialIntent?.extra?['fromWidget'] == 'tracker'){
      trackPrayerFunction();
    }

    _intentSub = receive_intent.ReceiveIntent.receivedIntentStream.listen((intent) {
      if (intent!.extra?['fromWidget'] == 'qibla') {
        showCompass();
      } else if (intent.extra?['fromWidget'] == 'tracker') {
        trackPrayerFunction();
      }
    });
  }

  void trackPrayerFunction() async {
    User? user = await FirebaseService.getUserInfo();
    if (user == null) {
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
      setState(() {
        isLoadingTracker = true;
      });
      PrayerService().trackPrayer(context, user.uid, prayerModel).then((value) {
        initAll();
      });
      setState(() {
        isLoadingTracker = false;
      });
    }
  }

  Future<void> setPrayerData(PrayerResult prayerResult) async {
    setState(() {
      prayerModel.fajrTime = tz.TZDateTime.from(prayerResult.prayerTimes.fajr!, prayerResult.location);
      prayerModel.dhuhrTime = tz.TZDateTime.from(prayerResult.prayerTimes.dhuhr!, prayerResult.location);
      prayerModel.asrTime = tz.TZDateTime.from(prayerResult.prayerTimes.asr!, prayerResult.location);
      prayerModel.maghribTime = tz.TZDateTime.from(prayerResult.prayerTimes.maghrib!, prayerResult.location);
      prayerModel.ishaTime = tz.TZDateTime.from(prayerResult.prayerTimes.isha!, prayerResult.location);
      DateTime nextTime;
      String prayerName;

      if (prayerResult.dateTime.isBefore(prayerModel.fajrTime!)) {
        prayerName = "Fajr";
        nextTime = prayerModel.fajrTime!;
      } else if (prayerResult.dateTime.isBefore(prayerModel.dhuhrTime!)) {
        prayerName = "Dhuhr";
        nextTime = prayerModel.dhuhrTime!;
      } else if (prayerResult.dateTime.isBefore(prayerModel.asrTime!)) {
        prayerName = "Asr";
        nextTime = prayerModel.asrTime!;
      } else if (prayerResult.dateTime.isBefore(prayerModel.maghribTime!)) {
        prayerName = "Maghrib";
        nextTime = prayerModel.maghribTime!;
      } else if (prayerResult.dateTime.isBefore(prayerModel.ishaTime!)) {
        prayerName = "Isha";
        nextTime = prayerModel.ishaTime!;
      } else {
        prayerName = "Fajr";
        nextTime = prayerModel.fajrTime!.add(const Duration(days: 1));
      }

      Duration remaining = nextTime.difference(prayerResult.dateTime);
      String hours = remaining.inHours.toString().padLeft(2, '0');
      String minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');

      nextPrayer = prayerName;
      nextPrayerTime = "in ${hours}h ${minutes}m";
      WidgetUpdate().updateWidgetPrayerTime(
          fajr: tz.TZDateTime.from(prayerResult.prayerTimes.fajr!, prayerResult.location),
          dhuhr:  tz.TZDateTime.from(prayerResult.prayerTimes.dhuhr!, prayerResult.location),
          asr:  tz.TZDateTime.from(prayerResult.prayerTimes.asr!, prayerResult.location),
          maghrib:  tz.TZDateTime.from(prayerResult.prayerTimes.maghrib!, prayerResult.location),
          isha:  tz.TZDateTime.from(prayerResult.prayerTimes.isha!, prayerResult.location)
      );
    });
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
            appVersion.isNotEmpty ? Text('v$appVersion', style: Theme.of(context).textTheme.bodySmall) : Container(),
            Spacer(),
            Visibility(
              visible: visibleLogout,
              child: GestureDetector(
                onTap: () => FirebaseService.logout().then((_) {
                    if (mounted) {
                      setState(() {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Logout successful")),
                        );
                        nickname = null;
                        todayPrayer = null;
                        yesterdayPrayer = null;
                        WidgetUpdate().updateWidgetPrayerTracker(prayerModel: null);
                      });
                    }
                }),
                child: Icon(Icons.logout),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.background, surfaceTintColor: Colors.transparent
      ),
      body: FutureBuilder(
        future: initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: RotatingDot());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error getting location data'));
          } else {
            return Container(
              padding: EdgeInsets.all(10),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assalamualaikum,', style: Theme.of(context).textTheme.bodyMedium),
                    Text(nickname != null ? '$nickname' : 'Guest', style: Theme.of(context).textTheme.headlineLarge),
                    SizedBox(height: 20,),
                    GestureDetector(
                      onTap: initAll,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          isGetLocation ? RotatingDot() : Icon(Icons.location_on, size: 20,),
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
                                showCompass();
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
                                Text(DateFormat('HH:mm').format(prayerModel.fajrTime!), style: Theme.of(context).textTheme.bodyMedium),
                                Text(DateFormat('HH:mm').format(prayerModel.dhuhrTime!), style: Theme.of(context).textTheme.bodyMedium),
                                Text(DateFormat('HH:mm').format(prayerModel.asrTime!), style: Theme.of(context).textTheme.bodyMedium),
                                Text(DateFormat('HH:mm').format(prayerModel.maghribTime!), style: Theme.of(context).textTheme.bodyMedium),
                                Text(DateFormat('HH:mm').format(prayerModel.ishaTime!), style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                GestureDetector(
                                    onTap: () => toggleNotification("Fajr", prayerModel.fajrTime!, 1),
                                    child: !prayerModel.fajrNotif ? Icon(Icons.notifications_active_outlined, size: 20) : Icon(Icons.notifications_off_outlined, size: 20)),
                                GestureDetector(
                                    onTap: () => toggleNotification("Dhuhr", prayerModel.dhuhrTime!, 2),
                                    child: !prayerModel.dhuhrNotif ? Icon(Icons.notifications_active_outlined, size: 20) : Icon(Icons.notifications_off_outlined, size: 20)),
                                GestureDetector(
                                    onTap: () => toggleNotification("Asr", prayerModel.asrTime!, 3),
                                    child: !prayerModel.asrNotif ? Icon(Icons.notifications_active_outlined, size: 20) : Icon(Icons.notifications_off_outlined, size: 20)),
                                GestureDetector(
                                    onTap: () => toggleNotification("Maghrib", prayerModel.maghribTime!, 4),
                                    child: !prayerModel.maghribNotif ? Icon(Icons.notifications_active_outlined, size: 20) : Icon(Icons.notifications_off_outlined, size: 20)),
                                GestureDetector(
                                    onTap: () => toggleNotification("Isha", prayerModel.ishaTime!, 5),
                                    child: !prayerModel.ishaNotif ? Icon(Icons.notifications_active_outlined, size: 20) : Icon(Icons.notifications_off_outlined, size: 20)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 10,),
                    GestureDetector(
                      onTap: () async {
                        User? user = await FirebaseService.getUserInfo();
                        if (user == null) {
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
                          bool refresh = await Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.rightToLeft,
                              childBuilder: (context) => History(user: user),
                            ),
                          );
                          if(refresh){
                            initAll();
                          }
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
                                      Text(DateFormat('EEEE').format(yesterdayDate), style: Theme.of(context).textTheme.bodyMedium),
                                      Text(DateFormat("dd MMMM yyyy").format(yesterdayDate),style: Theme.of(context).textTheme.bodyMedium),
                                      const SizedBox(height: 10),
                                      PrayerTile(prayerModel: yesterdayPrayer),
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
                                      Text(DateFormat('EEEE').format(todayDate), style: Theme.of(context).textTheme.bodyMedium),
                                      Text(DateFormat("dd MMMM yyyy").format(todayDate),style: Theme.of(context).textTheme.bodyMedium),
                                      const SizedBox(height: 10),
                                      PrayerTile(prayerModel: todayPrayer),
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
                                ? RotatingDot()
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
            );
          }
        }
      ),
    );
  }

  void toggleNotification(String prayerName, DateTime time, int id) async {
    setState(() {
      switch (id) {
        case 1: prayerModel.fajrNotif = !prayerModel.fajrNotif; PrefsService.savePrayerPrefs("fajr_notif", prayerModel.fajrNotif); break;
        case 2: prayerModel.dhuhrNotif = !prayerModel.dhuhrNotif; PrefsService.savePrayerPrefs("dhuhr_notif", prayerModel.dhuhrNotif); break;
        case 3: prayerModel.asrNotif = !prayerModel.asrNotif; PrefsService.savePrayerPrefs("asr_notif", prayerModel.asrNotif); break;
        case 4: prayerModel.maghribNotif = !prayerModel.maghribNotif; PrefsService.savePrayerPrefs("maghrib_notif", prayerModel.maghribNotif); break;
        case 5: prayerModel.ishaNotif = !prayerModel.ishaNotif; PrefsService.savePrayerPrefs("isha_notif", prayerModel.ishaNotif); break;
      }
    });

    if ((prayerModel.fajrNotif && id == 1) ||
        (prayerModel.dhuhrNotif && id == 2) ||
        (prayerModel.asrNotif && id == 3) ||
        (prayerModel.maghribNotif && id == 4) ||
        (prayerModel.ishaNotif && id == 5)) {
      // Schedule notification
      NotificationService.scheduleNotification(
        id: id,
        title: "Prayer Reminder",
        body: "$prayerName prayer will start in 5 minutes at ${DateFormat.Hm().format(time)}.",
        scheduledTime: time,
      );
      WidgetUpdate().updateWidgetPrayerNotification(name: prayerName, notification: true);
    } else {
      // Cancel notification
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.cancel(id);
      WidgetUpdate().updateWidgetPrayerNotification(name: prayerName, notification: false);
    }
  }

  Future<void> loadPrefs() async {
    prayerModel.fajrNotif = await PrefsService.getPrayerPrefs("fajr_notif");
    prayerModel.dhuhrNotif = await PrefsService.getPrayerPrefs("dhuhr_notif");
    prayerModel.asrNotif = await PrefsService.getPrayerPrefs("asr_notif");
    prayerModel.maghribNotif = await PrefsService.getPrayerPrefs("maghrib_notif");
    prayerModel.ishaNotif = await PrefsService.getPrayerPrefs("isha_notif");
    setState(() {});

    if (prayerModel.fajrTime != null &&
        prayerModel.dhuhrTime != null &&
        prayerModel.asrTime != null &&
        prayerModel.maghribTime != null &&
        prayerModel.ishaTime != null) {
      _rescheduleActiveNotifications();
    }
  }

  Future<void> _rescheduleActiveNotifications() async {
    DateTime adjustIfPast(DateTime time) {
      final now = DateTime.now();
      if (time.isBefore(now)) {
        return time.add(const Duration(days: 1)); // schedule for tomorrow
      }
      return time;
    }

    if (prayerModel.fajrTime != null && prayerModel.fajrNotif) {
      NotificationService.scheduleNotification(
        id: 1,
        title: "Prayer Reminder",
        body: "Fajr prayer will start in 5 minutes at ${DateFormat.Hm().format(prayerModel.fajrTime!)}.",
        scheduledTime: adjustIfPast(prayerModel.fajrTime!),
      );

      NotificationService.logNotification(adjustIfPast(prayerModel.fajrTime!), 1, true);
    }

    if (prayerModel.dhuhrTime != null && prayerModel.dhuhrNotif) {
      NotificationService.scheduleNotification(
        id: 2,
        title: "Prayer Reminder",
        body: "Dhuhr prayer will start in 5 minutes at ${DateFormat.Hm().format(prayerModel.dhuhrTime!)}.",
        scheduledTime: adjustIfPast(prayerModel.dhuhrTime!),
      );

      NotificationService.logNotification(adjustIfPast(prayerModel.dhuhrTime!), 2, true);
    }

    if (prayerModel.asrTime != null && prayerModel.asrNotif) {
      NotificationService.scheduleNotification(
        id: 3,
        title: "Prayer Reminder",
        body: "Asr prayer will start in 5 minutes at ${DateFormat.Hm().format(prayerModel.asrTime!)}.",
        scheduledTime: adjustIfPast(prayerModel.asrTime!),
      );

      NotificationService.logNotification(adjustIfPast(prayerModel.asrTime!), 3, true);
    }

    if (prayerModel.maghribTime != null && prayerModel.maghribNotif) {
      NotificationService.scheduleNotification(
        id: 4,
        title: "Prayer Reminder",
        body: "Maghrib prayer will start in 5 minutes at ${DateFormat.Hm().format(prayerModel.maghribTime!)}.",
        scheduledTime: adjustIfPast(prayerModel.maghribTime!),
      );

      NotificationService.logNotification(adjustIfPast(prayerModel.maghribTime!), 4, true);
    }

    if (prayerModel.ishaTime != null && prayerModel.ishaNotif) {
      NotificationService.scheduleNotification(
        id: 5,
        title: "Prayer Reminder",
        body: "Isha prayer will start in 5 minutes at ${DateFormat.Hm().format(prayerModel.ishaTime!)}.",
        scheduledTime: adjustIfPast(prayerModel.ishaTime!),
      );

      NotificationService.logNotification(adjustIfPast(prayerModel.ishaTime!), 5, true);
    }
  }

  showCompass() async {

    return showDialog(
        context: context,
        builder: (context) => Dialog(
            insetPadding: EdgeInsets.all(10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.background
              ),
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.close),
                      )
                    ],
                  ),
                  Text('Qibla Compass', style: Theme.of(context).textTheme.headlineMedium),
                  SizedBox(height: 10,),
                  Compass(),
                  SizedBox(height: 50,),
                ],
              ),
            )));
  }
}*/
