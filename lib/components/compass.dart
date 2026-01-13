import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import 'colors.dart';

class Compass extends StatefulWidget {
  const Compass({super.key});

  @override
  State<Compass> createState() => _CompassState();
}

class _CompassState extends State<Compass> {
  static const _kaabaLat = 21.422487;
  static const _kaabaLon = 39.826206;
  StreamSubscription<Position>? _posSub;
  double? _bearingToQibla;
  double _deg2rad(double d) => d * math.pi / 180.0;
  double _rad2deg(double r) => r * 180.0 / math.pi;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Optionally prompt user to enable location services
      await Geolocator.openLocationSettings();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return; // Show UI state that location is required
    }

    // Get last known first for snappy UI, then subscribe for updates
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      _updateBearing(last);
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best
      )
    );
    _updateBearing(pos);

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(_updateBearing);
  }

  void _updateBearing(Position pos) {
    final bearing = _initialBearing(
      pos.latitude,
      pos.longitude,
      _kaabaLat,
      _kaabaLon,
    );
    setState(() {
      _bearingToQibla = bearing;
    });
  }

  double _initialBearing(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = _deg2rad(lat1);
    final phi2 = _deg2rad(lat2);
    final dLon = _deg2rad(lon2 - lon1);

    final y = math.sin(dLon) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLon);
    final theta = math.atan2(y, x);
    final bearing = (_rad2deg(theta) + 360.0) % 360.0;
    return bearing;
  }

  double? _lastAngle;

  double _normalizeAngle(double newAngle) {
    if (_lastAngle == null) {
      _lastAngle = newAngle;
      return newAngle;
    }

    double delta = newAngle - _lastAngle!;

    // Wrap delta into [-π, π] to avoid long spins
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;

    _lastAngle = _lastAngle! + delta;
    return _lastAngle!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        final heading = snapshot.data?.heading;

        final hasSensor = snapshot.data?.heading != null && !heading!.isNaN;
        final canCompute = _bearingToQibla != null && hasSensor;

        final diffDegrees = canCompute
            ? ((_bearingToQibla! - heading) + 360.0) % 360.0
            : 0.0;
        final diffRadians = diffDegrees * math.pi / 180.0;
        final smoothedAngle = _normalizeAngle(diffRadians);

        return AspectRatio(
          aspectRatio: 1,
          child: Material(
            shape: CircleBorder(),
            clipBehavior: Clip.antiAlias,
            elevation: 4.0,
            child: Container(
              padding: EdgeInsets.all(16.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: smoothedAngle),
                duration: const Duration(milliseconds: 300),
                builder: (context, angle, child) {
                  return Transform.rotate(
                    angle: angle,
                    child: child,
                  );
                },
                child: Image.asset('assets/compass.png'),
              ),
          ),
          )
        );
      },
    );
  }
}

void showCompass(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: AppColors.background,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ),
              Text('Qibla Compass', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Compass(),
              const SizedBox(height: 50),
            ],
          ),
        ),
      );
    },
  );
}