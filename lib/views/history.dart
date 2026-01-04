import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:muslim_essential/services/colors.dart';

import '../main.dart';
import '../objectbox/prayer_database.dart';

class History extends StatefulWidget {
  const History({super.key});

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  List<PrayerDatabase> listData = [];

  @override
  void initState() {
    final box = objectbox.store.box<PrayerDatabase>();
    setState(() {
      listData = box.getAll();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    //final screenHeight = size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('Muslim Essential'), backgroundColor: AppColors.background, surfaceTintColor: Colors.transparent,),
      body: Container(
        width: screenWidth,
        padding: const EdgeInsets.only(top: 10, right: 10, left: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(DateTime.now()),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Container(
              padding: const EdgeInsets.all(8),
              child:  Row(
                children: [
                  Expanded(flex: 1, child: Text("Day", style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.start,)),
                  Expanded(flex: 2, child: Text("Fajr", style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text("Dhuhr", style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text("Asr", style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text("Maghrib", style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text("Isha", style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Icon(Icons.check_circle, color: AppColors.highlightBlue, size: 20,)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: listData.length,
                itemBuilder: (context, index) {
                  final data = listData[index];

                  String prayerDate = '';
                  int fajr = data.doneFajr ? 1 : 0;
                  int dhuhr = data.doneDhuhr ? 1 : 0;
                  int asr = data.doneAsr ? 1 : 0;
                  int maghrib = data.doneMaghrib ? 1 : 0;
                  int isha = data.doneIsha ? 1 : 0;
                  int prayerCompleted = fajr + dhuhr + asr + maghrib + isha;
                  IconData? prayerIconFajr = fajr == 1 ? Icons.check_circle : Icons.radio_button_unchecked;
                  IconData? prayerIconDhuhr = dhuhr == 1 ? Icons.check_circle : Icons.radio_button_unchecked;
                  IconData? prayerIconAsr = asr == 1 ? Icons.check_circle : Icons.radio_button_unchecked;
                  IconData? prayerIconMaghrib = maghrib == 1 ? Icons.check_circle : Icons.radio_button_unchecked;
                  IconData? prayerIconIsha = isha == 1 ? Icons.check_circle : Icons.radio_button_unchecked;

                  Color? prayerColorFajr = fajr == 1 ? AppColors.highlightBlue : AppColors.borderColor;
                  Color? prayerColorDhuhr = dhuhr == 1 ? AppColors.highlightBlue : AppColors.borderColor;
                  Color? prayerColorAsr = asr == 1 ? AppColors.highlightBlue : AppColors.borderColor;
                  Color? prayerColorMaghrib = maghrib == 1 ? AppColors.highlightBlue : AppColors.borderColor;
                  Color? prayerColorIsha = isha == 1 ? AppColors.highlightBlue : AppColors.borderColor;

                  final parts = data.date.split('-');
                  if (parts.length == 3) {
                    prayerDate =  parts[2]; // 01/09
                  }
                  return Container(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Expanded(flex: 1, child: Text(prayerDate, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.start,)),
                        Expanded(flex: 2, child: Icon(prayerIconFajr, color: prayerColorFajr, size: 20,)),
                        Expanded(flex: 2, child: Icon(prayerIconDhuhr, color: prayerColorDhuhr, size: 20)),
                        Expanded(flex: 2, child: Icon(prayerIconAsr, color: prayerColorAsr, size: 20)),
                        Expanded(flex: 2, child: Icon(prayerIconMaghrib, color: prayerColorMaghrib, size: 20)),
                        Expanded(flex: 2, child: Icon(prayerIconIsha, color: prayerColorIsha, size: 20)),
                        Expanded(flex: 1, child: Text("$prayerCompleted/5", style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.end)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
