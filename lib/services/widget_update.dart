import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../objectbox/prayer_database.dart';

class WidgetUpdate {
  Future<void> updateWidgetPrayerTime({
    required PrayerDatabase prayerDatabase
  }) async {
    await HomeWidget.saveWidgetData<String>('fajr_time', DateFormat('HH:mm').format(prayerDatabase.fajr));
    await HomeWidget.saveWidgetData<String>('dhuhr_time', DateFormat('HH:mm').format(prayerDatabase.dhuhr));
    await HomeWidget.saveWidgetData<String>('asr_time', DateFormat('HH:mm').format(prayerDatabase.asr));
    await HomeWidget.saveWidgetData<String>('maghrib_time', DateFormat('HH:mm').format(prayerDatabase.maghrib));
    await HomeWidget.saveWidgetData<String>('isha_time', DateFormat('HH:mm').format(prayerDatabase.isha));

    await HomeWidget.saveWidgetData<String>('date_time', DateFormat('dd MMMM yyyy').format(DateTime.now()));

    await HomeWidget.updateWidget(
      name: 'PrayerWidgetProvider',
    );
  }

  Future<void> updateWidgetLocation({required String location}) async {
    await HomeWidget.saveWidgetData<String>('location_name', location);
    await HomeWidget.updateWidget(
      name: 'PrayerWidgetProvider',
    );
  }

  Future<void> updateWidgetDate() async {
    final date = DateFormat("dd MMMM yyyy").format(DateTime.now());
    await HomeWidget.saveWidgetData<String>('date_time', date);
    await HomeWidget.updateWidget(
      name: 'PrayerWidgetProvider',
    );
  }

  Future<void> updateWidgetPrayerNotification({required PrayerDatabase prayerDatabase}) async {
    await HomeWidget.saveWidgetData<bool>('fajr_notification', prayerDatabase.notifFajr);
    await HomeWidget.saveWidgetData<bool>('dhuhr_notification', prayerDatabase.notifAsr);
    await HomeWidget.saveWidgetData<bool>('asr_notification', prayerDatabase.notifAsr);
    await HomeWidget.saveWidgetData<bool>('maghrib_notification', prayerDatabase.notifMaghrib);
    await HomeWidget.saveWidgetData<bool>('isha_notification', prayerDatabase.notifIsha);
    await HomeWidget.updateWidget(
      name: 'PrayerWidgetProvider',
    );
  }

  Future<void> updateWidgetPrayerTracker({required PrayerDatabase prayerDatabase}) async {
      await HomeWidget.saveWidgetData<bool>('fajr_check', prayerDatabase.doneFajr);
      await HomeWidget.saveWidgetData<bool>('dhuhr_check', prayerDatabase.doneDhuhr);
      await HomeWidget.saveWidgetData<bool>('asr_check', prayerDatabase.doneAsr);
      await HomeWidget.saveWidgetData<bool>('maghrib_check', prayerDatabase.doneMaghrib);
      await HomeWidget.saveWidgetData<bool>('isha_check', prayerDatabase.doneIsha);

    await HomeWidget.updateWidget(
      name: 'PrayerWidgetProvider',
    );
  }

  Future<void> schedulePrayerTimeUpdate({required String name, required int index, required DateTime time}) async {
    final ymd = DateFormat('yyyyMMdd').format(time);
    final key = '${ymd}_${index}_$name';

    await HomeWidget.saveWidgetData(
      key,
      DateFormat.Hm().format(time),
    );
  }
}