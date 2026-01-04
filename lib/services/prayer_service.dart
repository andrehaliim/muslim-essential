import 'dart:developer';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;
import 'package:shalat_essential/components/custom_snackbar.dart';
import 'package:timezone/data/latest.dart' as tzl;
import 'package:timezone/timezone.dart' as tz;

import '../main.dart';
import '../objectbox.g.dart';
import '../objectbox/prayer_database.dart';

class PrayerService {
  Future<bool> trackPrayer(BuildContext context, String userId) async {
    Box<PrayerDatabase> prayerBox = objectbox.store.box<PrayerDatabase>();
    final firestore = FirebaseFirestore.instance;

    DateTime currentDate = DateTime.now();
    String date = "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";
    final todayPrayer = prayerBox.query(PrayerDatabase_.date.equals(date)).build().findFirst();
    if (todayPrayer == null) {
      CustomSnackbar().failedSnackbar(context, 'Prayer data not available');
      return false;
    }

    final times = {
      "fajr": todayPrayer.fajr,
      "dhuhr": todayPrayer.dhuhr,
      "asr": todayPrayer.asr,
      "maghrib": todayPrayer.maghrib,
      "isha": todayPrayer.isha,
    };
      
    final currentPrayer = currentPrayerName(currentDate, times);

    final docRef = firestore
        .collection('tracker')
        .doc(userId)
        .collection('prayer')
        .doc(date);

    // today doc
    final todayDoc = await docRef.get();

    if (todayDoc.exists) {
      if (todayDoc.data()?.containsKey(currentPrayer) == true && todayDoc.data()?[currentPrayer] == 1) {
        CustomSnackbar().failedSnackbar(context, 'Already tracked prayer');
        return true;
      }

      // Not tracked yet → update
      await docRef.set({
        currentPrayer: 1,
      }, SetOptions(merge: true));

      CustomSnackbar().successSnackbar(context, '$currentPrayer tracked successfully');
    } else {
      Map<String, dynamic> toMap =
         {
          'fajr': todayPrayer.doneFajr ? 1 : 0,
          'dhuhr': todayPrayer.doneDhuhr ? 1 : 0,
          'asr': todayPrayer.doneAsr ? 1 : 0,
          'maghrib': todayPrayer.doneMaghrib ? 1 : 0,
          'isha': todayPrayer.doneIsha ? 1 : 0,
        };

      toMap[currentPrayer] = 1;
      await docRef.set(toMap);
    }

    switch (currentPrayer) {
      case 'fajr':
        todayPrayer.doneFajr = true;
        break;
      case 'dhuhr':
        todayPrayer.doneDhuhr = true;
        break;
      case 'asr':
        todayPrayer.doneAsr = true;
        break;
      case 'maghrib':
        todayPrayer.doneMaghrib = true;
        break;
      case 'isha':
        todayPrayer.doneIsha = true;
        break;
    }
    prayerBox.put(todayPrayer);
    return true;
  }

  String currentPrayerName(DateTime now, Map<String, DateTime?> times) {
    final orderedPrayers = [
      {"name": "fajr", "time": times["fajr"]!},
      {"name": "dhuhr", "time": times["dhuhr"]!},
      {"name": "asr", "time": times["asr"]!},
      {"name": "maghrib", "time": times["maghrib"]!},
      {"name": "isha", "time": times["isha"]!},
    ];

    String currentPrayer = "fajr";
    for (var prayer in orderedPrayers) {
      if (now.isAfter(prayer["time"] as DateTime)) {
        currentPrayer = prayer["name"] as String;
      }
    }
    return currentPrayer;
  }

  static Future<void> getShalatDataForMonth(Position position, String? userId) async {
    Box<PrayerDatabase> prayerBox = objectbox.store.box<PrayerDatabase>();
    
    prayerBox.removeAll();
    tzl.initializeTimeZones();

    double latitude = position.latitude;
    double longitude = position.longitude;
    Coordinates coordinates = Coordinates(latitude, longitude);

    final location = tz.getLocation(tzmap.latLngToTimezoneString(latitude, longitude));
    DateTime now = tz.TZDateTime.from(DateTime.now(), location);
    DateTime firstDay = DateTime(now.year, now.month, 1);
    DateTime lastDay = DateTime(now.year, now.month + 1, 0);

    CalculationParameters params = CalculationMethod.singapore();
    params.madhab = Madhab.shafi;

    for (int i = 0; i < lastDay.day; i++) {
      DateTime currentDate = firstDay.add(Duration(days: i));
      final firestore = FirebaseFirestore.instance;
      String date = "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";
      DocumentSnapshot<Map<String, dynamic>>? todayDoc;

      // today doc
      if(userId != null) {
        todayDoc = await firestore
            .collection('tracker')
            .doc(userId)
            .collection('prayer')
            .doc(date)
            .get();
      }

      PrayerTimes prayerTimes = PrayerTimes(
        coordinates: coordinates,
        date: tz.TZDateTime.from(currentDate, location),
        calculationParameters: params,
      );

      final convertedFajr = tz.TZDateTime.from(prayerTimes.fajr!, location);
      final convertedDhuhr = tz.TZDateTime.from(prayerTimes.dhuhr!, location);
      final convertedAsr = tz.TZDateTime.from(prayerTimes.asr!, location);
      final convertedMaghrib = tz.TZDateTime.from(prayerTimes.maghrib!, location);
      final convertedIsha = tz.TZDateTime.from(prayerTimes.isha!, location);
      PrayerDatabase prayerData = PrayerDatabase(
          date: date,
          fajr: convertedFajr,
          dhuhr: convertedDhuhr,
          asr: convertedAsr,
          maghrib: convertedMaghrib,
          isha: convertedIsha
      );

      if(todayDoc != null && todayDoc.exists){
        final data = todayDoc.data()!;
        prayerData
          ..doneFajr = data['fajr'] == 1
          ..doneDhuhr = data['dhuhr'] == 1
          ..doneAsr = data['asr'] == 1
          ..doneMaghrib = data['maghrib'] == 1
          ..doneIsha = data['isha'] == 1;
      }

      log('Prayer data for date $date is successfully inserted');
      prayerBox.put(prayerData);
    }
  }

  Future<void> resetDonePrayerDatabase() async {
    Box<PrayerDatabase> prayerBox = objectbox.store.box<PrayerDatabase>();
    final allPrayers = prayerBox.getAll();
    for(var prayer in allPrayers){
      prayer.doneFajr = false;
      prayer.doneDhuhr = false;
      prayer.doneAsr = false;
      prayer.doneMaghrib = false;
      prayer.doneIsha = false;
      prayerBox.put(prayer);
    }
  }
}