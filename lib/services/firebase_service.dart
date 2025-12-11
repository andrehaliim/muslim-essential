import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';
import '../objectbox.g.dart';
import '../objectbox/prayer_database.dart';

class FirebaseService {
  static Future<User?> getUserInfo() async {
    return FirebaseAuth.instance.currentUser;
  }

  static Future<String> loadNickname() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (doc.exists) {
        return doc.data()?["nickname"];
      }
    }
    return '';
  }

  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> getFirebasePrayers() async {
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
}