import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;
import 'package:muslim_essential/components/colors.dart';
import 'package:muslim_essential/components/compass.dart';
import 'package:muslim_essential/components/custom_snackbar.dart';
import 'package:muslim_essential/components/rotating_dot.dart';
import 'package:muslim_essential/main.dart';
import 'package:muslim_essential/objectbox.g.dart';
import 'package:muslim_essential/objectbox/location_database.dart';
import 'package:muslim_essential/objectbox/prayer_database.dart';
import 'package:muslim_essential/services/firebase_service.dart';
import 'package:muslim_essential/services/location_service.dart';
import 'package:muslim_essential/services/notification_service.dart';
import 'package:muslim_essential/services/prayer_service.dart';
import 'package:muslim_essential/services/prayer_tile.dart';
import 'package:muslim_essential/services/widget_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:receive_intent/receive_intent.dart' as receive_intent;

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  late Future<void> _initFuture;
  User? _firebaseUser;
  String _appVersion = '';
  late Box<PrayerDatabase> _prayerBox;
  late Box<LocationDatabase> _locationBox;
  late Position _currentPosition;
  String _positionName = '';
  String _timezoneName = '';
  PrayerDatabase? _todayPrayerData;
  PrayerDatabase? _yesterdayPrayerData;
  String _nextPrayerName = '';
  String _nextPrayerTimeLeft = '';
  bool _isLoadingInit = false;
  bool _isLoadingTracker = false;
  bool _isNewLocation = false;
  String _nickname = 'Guest';
  Timer? _minuteTimer;
  StreamSubscription<receive_intent.Intent?>? _intentSub;

  @override
  void initState() {
    super.initState();
    _startMinuteTimer();
    _listenForIntents();
    _getAppVersion();
    _locationBox = objectbox.store.box<LocationDatabase>();
    _prayerBox = objectbox.store.box<PrayerDatabase>();
    _initFuture = _checkUserAvailability().then((_) {
      if (_firebaseUser != null) {
        return _initAllWithUser(true);
      } else {
        return _initAll();
      }
    });
  }

  Future<void> _initAll() async {
    _showLoadingInit();
    await _getLocation();
    await _getPrayerData();
    await _getTodayYesterdayPrayerData();
    await _getNextPrayerInfo();
    await _updateAllWidgets();
    _showLoadingInit();
  }

  Future<void> _initAllWithUser(bool isInit) async {
    _showLoadingInit();
    if (isInit) {
      await _getLocation();
      await _getPrayerData();
    }
    _nickname = await FirebaseService().loadNickname();
    await PrayerService().getMonthlyFirebasePrayer();
    await _getTodayYesterdayPrayerData();
    await _getNextPrayerInfo();
    await _updateAllWidgets();
    _showLoadingInit();
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    _intentSub?.cancel();
    super.dispose();
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
            SizedBox(width: 10),
            Text('v$_appVersion', style: Theme.of(context).textTheme.bodySmall),
            Spacer(),
            Visibility(
              visible: _firebaseUser != null,
              child: GestureDetector(
                onTap: () => FirebaseService().logout().then((_) async {
                  if (mounted) {
                    CustomSnackbar().successSnackbar(context, 'Logout successful');
                    await PrayerService().resetDonePrayerDatabase();
                    await _checkUserAvailability();
                    if (_firebaseUser == null) {
                      setState(() {
                        _initFuture = _initAll();
                        _nickname = 'Guest';
                      });
                    }
                  }
                }),
                child: Icon(Icons.logout),
              ),
            ),
          ],
        ),
        titleSpacing: 10,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: RotatingDot(scale: 50));
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 10),
                  Text('Error: ${snapshot.error}'),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _initFuture = _checkUserAvailability().then((_) {
                        if (_firebaseUser != null) {
                          return _initAllWithUser(true);
                        } else {
                          return _initAll();
                        }
                      });
                    }),
                    child: Text('Retry', style: Theme.of(context).primaryTextTheme.labelLarge),
                  ),
                ],
              ),
            );
          } else {
            return Container(
              padding: EdgeInsets.all(10),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assalamualaikum,', style: Theme.of(context).textTheme.bodyMedium),
                    Text(_nickname, style: Theme.of(context).textTheme.headlineLarge),
                    SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on, size: 20),
                        Expanded(
                          child: Text(_positionName, style: Theme.of(context).textTheme.bodyMedium, maxLines: 2),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
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
                                Text(_nextPrayerName, style: Theme.of(context).textTheme.headlineLarge),
                                Text(_nextPrayerTimeLeft, style: Theme.of(context).textTheme.bodyMedium),
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
                    SizedBox(height: 10),
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
                                Text(
                                  _todayPrayerData != null
                                      ? DateFormat('HH:mm').format(_todayPrayerData!.fajr)
                                      : '--:--',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Text(
                                  _todayPrayerData != null
                                      ? DateFormat('HH:mm').format(_todayPrayerData!.dhuhr)
                                      : '--:--',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Text(
                                  _todayPrayerData != null
                                      ? DateFormat('HH:mm').format(_todayPrayerData!.asr)
                                      : '--:--',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Text(
                                  _todayPrayerData != null
                                      ? DateFormat('HH:mm').format(_todayPrayerData!.maghrib)
                                      : '--:--',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Text(
                                  _todayPrayerData != null
                                      ? DateFormat('HH:mm').format(_todayPrayerData!.isha)
                                      : '--:--',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: () => _toggleNotification(1),
                                  child: (_todayPrayerData?.notifFajr ?? false)
                                      ? Icon(Icons.notifications_active_outlined, size: 20)
                                      : Icon(Icons.notifications_off_outlined, size: 20),
                                ),
                                GestureDetector(
                                  onTap: () => _toggleNotification(2),
                                  child: (_todayPrayerData?.notifDhuhr ?? false)
                                      ? Icon(Icons.notifications_active_outlined, size: 20)
                                      : Icon(Icons.notifications_off_outlined, size: 20),
                                ),
                                GestureDetector(
                                  onTap: () => _toggleNotification(3),
                                  child: (_todayPrayerData?.notifAsr ?? false)
                                      ? Icon(Icons.notifications_active_outlined, size: 20)
                                      : Icon(Icons.notifications_off_outlined, size: 20),
                                ),
                                GestureDetector(
                                  onTap: () => _toggleNotification(4),
                                  child: (_todayPrayerData?.notifMaghrib ?? false)
                                      ? Icon(Icons.notifications_active_outlined, size: 20)
                                      : Icon(Icons.notifications_off_outlined, size: 20),
                                ),
                                GestureDetector(
                                  onTap: () => _toggleNotification(5),
                                  child: (_todayPrayerData?.notifIsha ?? false)
                                      ? Icon(Icons.notifications_active_outlined, size: 20)
                                      : Icon(Icons.notifications_off_outlined, size: 20),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    GestureDetector(
                      onTap: () async {
                        if (_firebaseUser == null) {
                          Navigator.pushNamed(context, '/login').then((_) async {
                            await _checkUserAvailability();
                            if (_firebaseUser != null) {
                              setState(() {
                                _initFuture = _initAllWithUser(false);
                              });
                            }
                          });
                        } else {
                          Navigator.pushNamed(context, '/history');
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
                                        child: Text(
                                          'Yesterday',
                                          style: Theme.of(context).textTheme.headlineMedium,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('EEEE').format(DateTime.now().subtract(Duration(days: 1))),
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                      Text(
                                        DateFormat("dd MMMM yyyy").format(DateTime.now().subtract(Duration(days: 1))),
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 10),
                                      PrayerTile(prayerDatabase: _yesterdayPrayerData!),
                                    ],
                                  ),
                                ),
                                const VerticalDivider(thickness: 2, width: 40),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: screenWidth,
                                        height: screenHeight / 25,
                                        child: Text(
                                          'Today',
                                          style: Theme.of(context).textTheme.headlineMedium,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('EEEE').format(DateTime.now()),
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                      Text(
                                        DateFormat("dd MMMM yyyy").format(DateTime.now()),
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 10),
                                      PrayerTile(prayerDatabase: _todayPrayerData!),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            width: screenWidth,
                            height: kMinInteractiveDimension,
                            child: ElevatedButton(
                              style: Theme.of(context).elevatedButtonTheme.style,
                              onPressed: _trackPrayerFunction,
                              child: _isLoadingTracker
                                  ? RotatingDot(scale: 20)
                                  : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_box_outlined, size: 30, color: AppColors.primaryText),
                                  Text('Track Prayer', style: Theme.of(context).primaryTextTheme.labelLarge),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _getAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version;
    });
  }

  Future<void> _checkUserAvailability() async {
    _firebaseUser = await FirebaseService().getUserInfo();
  }

  Future<void> _getLocation() async {
    final lastLocation = _locationBox.query().order(LocationDatabase_.id, flags: Order.descending).build().findFirst();
    _currentPosition = await LocationService().determinePosition();

    if (lastLocation == null) {
      _positionName = await LocationService().getLocationName(_currentPosition);
      _timezoneName = tzmap.latLngToTimezoneString(_currentPosition.latitude, _currentPosition.longitude);

      LocationDatabase locationDatabase = LocationDatabase(
        name: _positionName,
        latitude: _currentPosition.latitude,
        longitude: _currentPosition.longitude,
        timezone: _timezoneName,
      );
      _locationBox.put(locationDatabase);
      _isNewLocation = true;
    } else {
      double distanceInMeters = Geolocator.distanceBetween(
        _currentPosition.latitude,
        _currentPosition.longitude,
        lastLocation.latitude,
        lastLocation.longitude,
      );
      if (distanceInMeters > 100) {
        _positionName = await LocationService().getLocationName(_currentPosition);
        _timezoneName = tzmap.latLngToTimezoneString(_currentPosition.latitude, _currentPosition.longitude);

        LocationDatabase locationDatabase = LocationDatabase(
          name: _positionName,
          latitude: _currentPosition.latitude,
          longitude: _currentPosition.longitude,
          timezone: _timezoneName,
        );
        _locationBox.put(locationDatabase);
        _isNewLocation = true;
      } else {
        _positionName = lastLocation.name;
        _timezoneName = lastLocation.timezone;
      }
    }
  }

  Future<void> _getPrayerData() async {
    bool shouldFetch = _prayerBox.isEmpty();

    if (!shouldFetch) {
      final firstData = _prayerBox.getAll().firstOrNull;

      if (firstData != null) {
        DateTime storedDate = DateFormat("yyyy-MM-dd").parse(firstData.date);
        DateTime now = DateTime.now();

        if (storedDate.month != now.month || storedDate.year != now.year || _isNewLocation) {
          shouldFetch = true;
        }
      }
    }

    if (shouldFetch) {
      await PrayerService().getMonthlyPrayerData(_prayerBox, _locationBox, context);
    }
  }

  Future<void> _getTodayYesterdayPrayerData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final String todayDateString = DateFormat('yyyy-MM-dd').format(now);
    final String yesterdayDateString = DateFormat('yyyy-MM-dd').format(yesterday);

    final todayData = _prayerBox.query(PrayerDatabase_.date.equals(todayDateString)).build().findFirst();
    final yesterdayData = _prayerBox.query(PrayerDatabase_.date.equals(yesterdayDateString)).build().findFirst();

    setState(() {
      _todayPrayerData = todayData;
      _yesterdayPrayerData = yesterdayData;
      if(todayData != null) {NotificationService().scheduleAllNotification(todayData);}
    });
  }

  Future<void> _getNextPrayerInfo() async {
    final now = DateTime.now();
    Map<String, dynamic> nextPrayer = PrayerService().getNextPrayer(now, _prayerBox);

    Duration diff = nextPrayer['time'].difference(now);

    int hours = diff.inHours;
    int minutes = diff.inMinutes.remainder(60);

    String timeRemaining = "";
    if (hours > 0) {
      timeRemaining += "$hours ${hours == 1 ? 'Hour' : 'Hours'} ";
    }
    if (minutes > 0 || hours == 0) {
      timeRemaining += "$minutes ${minutes == 1 ? 'Minute' : 'Minutes'}";
    }
    timeRemaining += " Left";

    setState(() {
      _nextPrayerName = nextPrayer['name'];
      _nextPrayerTimeLeft = timeRemaining;
    });
  }

  Future<void> _updateAllWidgets() async {
    WidgetUpdate().updateWidgetLocation(location: _positionName);
    WidgetUpdate().updateWidgetDate();
    WidgetUpdate().updateWidgetPrayerTime(prayerDatabase: _todayPrayerData!);
    WidgetUpdate().updateWidgetPrayerNotification(prayerDatabase: _todayPrayerData!);
    WidgetUpdate().updateWidgetPrayerTracker(prayerDatabase: _todayPrayerData!);
  }

  void _showLoadingInit() {
    setState(() {
      _isLoadingInit = !_isLoadingInit;
    });
  }

  void _showLoadingTracker() {
    setState(() {
      _isLoadingTracker = !_isLoadingTracker;
    });
  }

  void _startMinuteTimer() {
    _minuteTimer?.cancel();
    _scheduleNextMinuteUpdate();
  }

  void _scheduleNextMinuteUpdate() {
    final now = DateTime.now();
    final delay = Duration(milliseconds: 60000 - (now.second * 1000 + now.millisecond));

    _minuteTimer = Timer(delay, () {
      if (mounted) {
        _getNextPrayerInfo();
        _scheduleNextMinuteUpdate();
      }
    });
  }

  void _toggleNotification(int id) async {
    bool isEnabled = false;
    String prayerName = '';
    DateTime time = DateTime.now();

    switch (id) {
      case 1:
        prayerName = 'Fajr';
        time = _todayPrayerData!.fajr;
        isEnabled = !_todayPrayerData!.notifFajr;
        break;
      case 2:
        prayerName = 'Dhuhr';
        time = _todayPrayerData!.dhuhr;
        isEnabled = !_todayPrayerData!.notifDhuhr;
        break;
      case 3:
        prayerName = 'Asr';
        time = _todayPrayerData!.asr;
        isEnabled = !_todayPrayerData!.notifAsr;
        break;
      case 4:
        prayerName = 'Maghrib';
        time = _todayPrayerData!.maghrib;
        isEnabled = !_todayPrayerData!.notifMaghrib;
        break;
      case 5:
        prayerName = 'Isha';
        time = _todayPrayerData!.isha;
        isEnabled = !_todayPrayerData!.notifIsha;
        break;
      default:
        return;
    }

    setState(() {
      final allPrayers = _prayerBox.getAll();

      for (var prayer in allPrayers) {
        if (id == 1) prayer.notifFajr = isEnabled;
        if (id == 2) prayer.notifDhuhr = isEnabled;
        if (id == 3) prayer.notifAsr = isEnabled;
        if (id == 4) prayer.notifMaghrib = isEnabled;
        if (id == 5) prayer.notifIsha = isEnabled;
      }

      _prayerBox.putMany(allPrayers);
    });

    if(isEnabled){
      NotificationService.scheduleNotification(
        id: id,
        title: "Prayer Reminder",
        body: "$prayerName prayer is at ${DateFormat.Hm().format(time)}.",
        scheduledTime: time,
      );
    } else {
      NotificationService.cancel(id);
    }

    WidgetUpdate().updateWidgetPrayerNotification(prayerDatabase: _todayPrayerData!);
    CustomSnackbar().successSnackbar(context, "Notification is ${isEnabled ? 'enabled' : 'disabled'} for $prayerName.");
    await _getTodayYesterdayPrayerData();
  }

  void _listenForIntents() async {
    final initialIntent = await receive_intent.ReceiveIntent.getInitialIntent();
    if (initialIntent?.extra?['fromWidget'] == 'qibla') {
      showCompass(context);
    } else if (initialIntent?.extra?['fromWidget'] == 'tracker') {
      //trackPrayerFunction();
    }

    _intentSub = receive_intent.ReceiveIntent.receivedIntentStream.listen((intent) {
      if (intent!.extra?['fromWidget'] == 'qibla') {
        showCompass(context);
      } else if (intent.extra?['fromWidget'] == 'tracker') {
        //trackPrayerFunction();
      }
    });
  }

  void _trackPrayerFunction() async {
    _showLoadingTracker();
    if (_firebaseUser == null) {
      Navigator.pushNamed(context, '/login').then((_) async {
        await _checkUserAvailability();
        if (_firebaseUser != null) {
          bool success = await PrayerService().trackPrayer(context, _todayPrayerData!);
          if(success) {
            WidgetUpdate().updateWidgetPrayerTracker(prayerDatabase: _todayPrayerData!);
          }
          setState(() {
            _initFuture = _initAllWithUser(false);
          });
        }
      });
    } else {
      bool success = await PrayerService().trackPrayer(context, _todayPrayerData!);
      if(success) {
        WidgetUpdate().updateWidgetPrayerTracker(prayerDatabase: _todayPrayerData!);
      }
      setState(() {
        _initFuture = _initAllWithUser(false);
      });
    }
    _showLoadingTracker();
  }
}