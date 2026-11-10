import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/api/user_service.dart';
import 'package:nimiro/common/widget/confirmation_dialog.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/user_model/user_model.dart';

/// Why a location request failed. Callers use this to show an honest message
/// instead of silently switching to another feed.
enum LocationFailureReason {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unavailable,
}

class LocationFailure implements Exception {
  final LocationFailureReason reason;
  final String message;

  const LocationFailure(this.reason, this.message);

  @override
  String toString() => message;
}

class LocationService {
  LocationService._();

  static final instance = LocationService._();

  Future<Position> getCurrentLocation(
      {bool isPermissionDialogShow = false}) async {
    // 1. Device location switch. This is the only case where the user must
    //    leave the app for the system location settings.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (isPermissionDialogShow) {
        await showServiceDialog();
      }
      throw const LocationFailure(LocationFailureReason.serviceDisabled,
          'Location services are disabled.');
    }

    // 2. Runtime permission. Request it exactly once: the old code asked
    //    twice, ignored the result, and always threw afterwards — so tapping
    //    "Allow" looked like it did nothing.
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      // The system prompt was just shown and the user declined. Android can
      // still ask again later, so sending them to Settings here is wrong.
      throw const LocationFailure(LocationFailureReason.permissionDenied,
          'Location permission was denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      // Only a permanent denial requires the app settings page.
      if (isPermissionDialogShow) {
        await showPermissionDialog();
      }
      throw const LocationFailure(LocationFailureReason.permissionDeniedForever,
          'Location permission is permanently denied.');
    }

    // 3. We have whileInUse/always now. Fetch a fresh fix; fall back to the
    //    last known position only when the device cannot produce one in time.
    try {
      return await getCurrentPosition();
    } on TimeoutException {
      final lastKnown = await Geolocator.getLastKnownPosition();
      // A stale fix from another city would make "nearby" wrong again. Only
      // reuse the last known position when it is recent.
      if (lastKnown != null &&
          DateTime.now().difference(lastKnown.timestamp).inMinutes <= 10) {
        _syncUserLocation(lastKnown);
        return lastKnown;
      }
      throw const LocationFailure(LocationFailureReason.timeout,
          'Could not get the current location in time.');
    } on LocationServiceDisabledException {
      if (isPermissionDialogShow) {
        await showServiceDialog();
      }
      throw const LocationFailure(LocationFailureReason.serviceDisabled,
          'Location services were disabled.');
    } on PermissionDeniedException {
      throw const LocationFailure(LocationFailureReason.permissionDenied,
          'Location permission was denied.');
    }
  }

  Future<Position> getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    _syncUserLocation(position);
    return position;
  }

  /// Keeps the server-side user coordinates fresh for features that rank by
  /// city. It never blocks the nearby request and never surfaces an error to
  /// the user: a failed profile update must not hide real nearby posts.
  void _syncUserLocation(Position position) {
    final User? user = SessionManager.instance.getUser();

    final double userLatitude = user?.lat?.toDouble() ?? 0;
    final double userLongitude = user?.lon?.toDouble() ?? 0;

    // Check if position has changed significantly (~11 meters).
    const double locationPrecision = 0.0001;
    final bool hasLocationChanged =
        (position.latitude - userLatitude).abs() > locationPrecision ||
            (position.longitude - userLongitude).abs() > locationPrecision;

    if (!hasLocationChanged) {
      return;
    }

    unawaited(UserService.instance
        .updateUserDetails(lat: position.latitude, lon: position.longitude)
        .catchError((Object error) {
      Loggers.error('Update user location failed: $error');
      return null;
    }));
  }

  Future<void> showPermissionDialog() async {
    await Get.bottomSheet(ConfirmationSheet(
      title: LKey.nearbyReelsPermissionTitle.tr,
      description: LKey.nearbyReelsPermissionDescription.tr,
      onTap: () {
        openAppSettings();
      },
    ));
  }

  Future<void> showServiceDialog() async {
    await Get.bottomSheet(ConfirmationSheet(
      title: LKey.locationServicesDisabledTitle.tr,
      description: LKey.locationServicesDisabledDescription.tr,
      onTap: () async {
        await Geolocator.openLocationSettings();
      },
    ));
  }
}
