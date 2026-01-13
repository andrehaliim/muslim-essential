import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<void> locationPermission() async {
    LocationPermission permission;

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        await SystemNavigator.pop();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await SystemNavigator.pop();
      return;
    }
  }

  Future<Position> determinePosition() async {
    bool serviceEnabled;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    await locationPermission();

    return Geolocator.getCurrentPosition();
  }

  Future<String> getLocationName(Position position) async {
    final latitude = position.latitude;
    final longitude = position.longitude;

    await setLocaleIdentifier("en_US");
    List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
    if (placemarks.isNotEmpty) {
      final place = placemarks.first;
      String location = '${place.subAdministrativeArea}, ${place.administrativeArea}, ${place.country}';
      return location;
    } else {
      return '-';
    }
  }
}