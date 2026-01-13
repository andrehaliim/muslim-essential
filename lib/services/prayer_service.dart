import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:muslim_essential/components/custom_snackbar.dart';
import 'package:muslim_essential/main.dart';
import 'package:muslim_essential/objectbox.g.dart';
import 'package:muslim_essential/objectbox/location_database.dart';
import 'package:muslim_essential/objectbox/prayer_database.dart';

class PrayerService {
  DateTime _parseDateTime(String timeStr, String dateStr) {
    final cleanTime = timeStr.split(' ')[0];
    return DateFormat("dd-MM-yyyy HH:mm").parse("$dateStr $cleanTime");
  }

  Future<void> getMonthlyPrayerData(Box<PrayerDatabase> prayerBox, Box<LocationDatabase> locationBox, BuildContext context) async {
    final savedLocation = locationBox.getAll().firstOrNull;
    if (savedLocation == null) return;

    //final firstPrayerRecord = prayerBox.getAll().isNotEmpty ? prayerBox.getAll().first : null;

    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    final lat = savedLocation.latitude;
    final lon = savedLocation.longitude;
    final timezone = savedLocation.timezone;

    final url = Uri.parse(
        'https://api.aladhan.com/v1/calendar/$year/$month?latitude=$lat&longitude=$lon&timezonestring=$timezone&method=20'
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = json.decode(response.body);
        final List<dynamic> data = decodedData['data'];

        List<PrayerDatabase> prayersToSave = [];

        for (var dayData in data) {
          final timings = dayData['timings'];
          final gregorianDate = dayData['date']['gregorian']['date'];
          DateTime parsedDate = DateFormat("dd-MM-yyyy").parse(gregorianDate);
          final formattedDate = DateFormat("yyyy-MM-dd").format(parsedDate);

          final prayerEntry = PrayerDatabase(
            date: formattedDate,
            fajr: _parseDateTime(timings['Fajr'], gregorianDate),
            dhuhr: _parseDateTime(timings['Dhuhr'], gregorianDate),
            asr: _parseDateTime(timings['Asr'], gregorianDate),
            maghrib: _parseDateTime(timings['Maghrib'], gregorianDate),
            isha: _parseDateTime(timings['Isha'], gregorianDate),
          );

          prayersToSave.add(prayerEntry);
        }

        prayerBox.removeAll();
        prayerBox.putMany(prayersToSave);
      }
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar().failedSnackbar(context, 'Error: $e');
      }
    }
  }

  Map<String, dynamic> getNextPrayer(DateTime now, Box<PrayerDatabase> prayerBox) {
    final String todayStr = DateFormat("yyyy-MM-dd").format(now);
    final todayPrayer = prayerBox.query(PrayerDatabase_.date.equals(todayStr)).build().findFirst();

    if (todayPrayer == null) return {'name': '-', 'time': now};

    if (now.isBefore(todayPrayer.fajr)) return {'name': 'Fajr', 'time': todayPrayer.fajr};
    if (now.isBefore(todayPrayer.dhuhr)) return {'name': 'Dhuhr', 'time': todayPrayer.dhuhr};
    if (now.isBefore(todayPrayer.asr)) return {'name': 'Asr', 'time': todayPrayer.asr};
    if (now.isBefore(todayPrayer.maghrib)) return {'name': 'Maghrib', 'time': todayPrayer.maghrib};
    if (now.isBefore(todayPrayer.isha)) return {'name': 'Isha', 'time': todayPrayer.isha};

    final tomorrowStr = DateFormat("yyyy-MM-dd").format(now.add(const Duration(days: 1)));
    final tomorrowPrayer = prayerBox.query(PrayerDatabase_.date.equals(tomorrowStr)).build().findFirst();

    return {
      'name': 'Fajr',
      'time': tomorrowPrayer?.fajr ?? todayPrayer.fajr.add(const Duration(hours: 24))
    };
  }

  Future<void> getMonthlyFirebasePrayer() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final now = DateTime.now();
      final year = now.year;
      final month = now.month;

      final startDate = "$year-${month.toString().padLeft(2, '0')}-01";
      final nextMonth = month == 12 ? DateTime(year + 1, 1) : DateTime(year, month + 1);
      final endDate = "${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}-01";

      final querySnapshot = await FirebaseFirestore.instance
          .collection('tracker')
          .doc(user.uid)
          .collection('prayer')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDate)
          .where(FieldPath.documentId, isLessThan: endDate)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return;
      }

      final prayerBox = objectbox.store.box<PrayerDatabase>();
      final localPrayers = prayerBox.getAll();
      if (localPrayers.isEmpty) {
        return;
      }

      for(var doc in querySnapshot.docs) {
        PrayerDatabase? update = prayerBox.query(PrayerDatabase_.date.equals(doc.id)).build().findFirst();
        if(update != null){
          update.doneFajr = doc['fajr'] == 1;
          update.doneDhuhr = doc['dhuhr'] == 1;
          update.doneAsr = doc['asr'] == 1;
          update.doneMaghrib = doc['maghrib'] == 1;
          update.doneIsha = doc['isha'] == 1;
          prayerBox.put(update);
        }
      }
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

  Future<bool> trackPrayer(BuildContext context, PrayerDatabase todayPrayerData) async {
    final firestore = FirebaseFirestore.instance;
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final now = DateTime.now();
    String currentPrayer = "fajr";
    String date = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final orderedPrayers = [
      {"name": "fajr", "time": todayPrayerData.fajr},
      {"name": "dhuhr", "time": todayPrayerData.dhuhr},
      {"name": "asr", "time": todayPrayerData.asr},
      {"name": "maghrib", "time": todayPrayerData.maghrib},
      {"name": "isha", "time": todayPrayerData.isha},
    ];

    for (var prayer in orderedPrayers) {
      if (now.isAfter(prayer["time"] as DateTime)) {
        currentPrayer = prayer["name"] as String;
      }
    }

    final docRef = firestore
        .collection('tracker')
        .doc(userId)
        .collection('prayer')
        .doc(date);

    final todayDoc = await docRef.get();

    if (todayDoc.exists) {
      if (todayDoc.data()?.containsKey(currentPrayer) == true && todayDoc.data()?[currentPrayer] == 1) {
        CustomSnackbar().failedSnackbar(context, 'Already tracked prayer');
        return false;
      }

      // Not tracked yet → update
      await docRef.set({
        currentPrayer: 1,
      }, SetOptions(merge: true));

      updateDatabaseAfterTrack(context, todayPrayerData, currentPrayer);
      CustomSnackbar().successSnackbar(context, '$currentPrayer tracked successfully');
      return true;
    } else {
      Map<String, dynamic> prayerMap = {
        'fajr': todayPrayerData.doneFajr ? 1 : 0,
        'dhuhr': todayPrayerData.doneDhuhr ? 1 : 0,
        'asr': todayPrayerData.doneAsr ? 1 : 0,
        'maghrib': todayPrayerData.doneMaghrib ? 1 : 0,
        'isha': todayPrayerData.doneIsha ? 1 : 0,
      };

      prayerMap[currentPrayer] = 1;

      await docRef.set(prayerMap);

      updateDatabaseAfterTrack(context, todayPrayerData, currentPrayer);
      CustomSnackbar().successSnackbar(context, '$currentPrayer tracked successfully');
      return true;
    }
  }

  void updateDatabaseAfterTrack(BuildContext context, PrayerDatabase todayPrayerData, String currentPrayer) {
    Box<PrayerDatabase> prayerBox = objectbox.store.box<PrayerDatabase>();
    switch (currentPrayer) {
      case 'fajr': todayPrayerData.doneFajr = true; break;
      case 'dhuhr': todayPrayerData.doneDhuhr = true; break;
      case 'asr': todayPrayerData.doneAsr = true; break;
      case 'maghrib': todayPrayerData.doneMaghrib = true; break;
      case 'isha': todayPrayerData.doneIsha = true; break;
    }

    prayerBox.put(todayPrayerData);
  }

/*Future<bool> trackPrayer(BuildContext context, String userId) async {
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
  }*/
}