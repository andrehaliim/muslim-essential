import 'package:flutter/material.dart';
import 'package:muslim_essential/components/colors.dart';
import 'package:muslim_essential/objectbox/prayer_database.dart';

class PrayerTile extends StatelessWidget {
  final PrayerDatabase? prayerDatabase;

  const PrayerTile({
    super.key,
    this.prayerDatabase,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (prayerDatabase != null) {
      int fajr = prayerDatabase!.doneFajr ? 1 : 0;
      int dhuhr = prayerDatabase!.doneDhuhr ? 1 : 0;
      int asr = prayerDatabase!.doneAsr ? 1 : 0;
      int maghrib = prayerDatabase!.doneMaghrib ? 1 : 0;
      int isha = prayerDatabase!.doneIsha ? 1 : 0;
      int completed = fajr + dhuhr + asr + maghrib + isha;

      return Column(
        children: [
          item(context: context, donePraying: prayerDatabase!.doneFajr, namePrayer: 'Fajr'),
          item(context: context, donePraying: prayerDatabase!.doneDhuhr, namePrayer: 'Dhuhr'),
          item(context: context, donePraying: prayerDatabase!.doneAsr, namePrayer: 'Asr'),
          item(context: context, donePraying: prayerDatabase!.doneMaghrib, namePrayer: 'Maghrib'),
          item(context: context, donePraying: prayerDatabase!.doneIsha, namePrayer: 'Isha'),
          const SizedBox(height: 20),
          SizedBox(
            width: screenWidth,
            child: Text('Completed: $completed/5',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
          ),
        ],
      );
    } else {
      return Text('No data', style: Theme.of(context).textTheme.bodyMedium);
    }
  }

  Row item({required BuildContext context, required bool donePraying, required String namePrayer}) {
    return Row(
      children: [
        Icon(
          donePraying
              ? Icons.check_circle
              : Icons.radio_button_unchecked,
          color: donePraying
              ? AppColors.highlightBlue
              : AppColors.borderColor,
          size: 20,
        ),
        const SizedBox(width: 10),
        Text(namePrayer, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}