import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'utils/logging_utils.dart';

/// Coordinates permission requests to prevent conflicts and ensure proper sequential handling
class PermissionCoordinator {
  static final PermissionCoordinator _instance = PermissionCoordinator._internal();
  factory PermissionCoordinator() => _instance;
  PermissionCoordinator._internal();

  // Permission state tracking
  bool _notificationPermissionRequested = false;
  bool _locationPermissionRequested = false;
  bool _isRequestingPermissions = false;

  // Callbacks for when permissions are ready
  final List<VoidCallback> _locationPermissionCallbacks = [];

  /// Request notification permissions first
  Future<PermissionStatus> requestNotificationPermissions() async {
    if (_isRequestingPermissions) {
      LoggingUtils.logWarning('Permission request already in progress, waiting...');
      // Wait for current request to complete
      while (_isRequestingPermissions) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    _isRequestingPermissions = true;
    LoggingUtils.logDebug('Starting notification permission request');

    try {
      // Check current status
      var status = await Permission.notification.status;
      LoggingUtils.logDebug('Current notification permission status: $status');

      if (status.isDenied) {
        LoggingUtils.logDebug('Requesting notification permission...');
        status = await Permission.notification.request();
        LoggingUtils.logDebug('Notification permission result: $status');
      }

      _notificationPermissionRequested = true;
      LoggingUtils.logDebug('Notification permissions completed');

      // Wait a moment to ensure permission dialogs are fully processed
      await Future.delayed(const Duration(milliseconds: 500));

      return status;
    } finally {
      _isRequestingPermissions = false;
    }
  }

  /// Request schedule exact alarm permission (Android 12+)
  Future<PermissionStatus> requestScheduleExactAlarmPermission() async {
    if (_isRequestingPermissions) {
      LoggingUtils.logWarning('Permission request already in progress, waiting...');
      // Wait for current request to complete
      while (_isRequestingPermissions) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    _isRequestingPermissions = true;
    LoggingUtils.logDebug('Starting schedule exact alarm permission request');

    try {
      // Check schedule exact alarm permission
      var alarmStatus = await Permission.scheduleExactAlarm.status;
      LoggingUtils.logDebug('Current schedule exact alarm permission status: $alarmStatus');

      if (alarmStatus.isDenied) {
        LoggingUtils.logDebug('Requesting schedule exact alarm permission...');
        alarmStatus = await Permission.scheduleExactAlarm.request();
        LoggingUtils.logDebug('Schedule exact alarm permission result: $alarmStatus');
      }

      LoggingUtils.logDebug('Schedule exact alarm permission check completed');

      return alarmStatus;
    } finally {
      _isRequestingPermissions = false;
    }
  }

  /// Request location permissions only after notification permissions are complete
  Future<LocationPermission> requestLocationPermissions() async {
    // Ensure notification permissions are requested first
    if (!_notificationPermissionRequested) {
      LoggingUtils.logDebug('Notification permissions not yet requested, requesting first...');
      await requestNotificationPermissions();
    }

    // Wait for any ongoing permission requests to complete
    if (_isRequestingPermissions) {
      LoggingUtils.logWarning('Permission request in progress, waiting...');
      while (_isRequestingPermissions) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    _isRequestingPermissions = true;
    LoggingUtils.logDebug('Starting location permission request');

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        LoggingUtils.logWarning('Location services are disabled');
        return LocationPermission.denied;
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      LoggingUtils.logDebug('Current location permission status: $permission');

      if (permission == LocationPermission.denied) {
        LoggingUtils.logDebug('Requesting location permission...');
        permission = await Geolocator.requestPermission();
        LoggingUtils.logDebug('Location permission result: $permission');
      }

      // Request background location permission if we have basic location access
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        LoggingUtils.logDebug('Requesting background location permission for better background functionality...');
        try {
          final backgroundStatus = await Permission.locationAlways.status;
          LoggingUtils.logDebug('Current background location status: $backgroundStatus');
          
          if (backgroundStatus.isDenied) {
            final backgroundResult = await Permission.locationAlways.request();
            LoggingUtils.logDebug('Background location permission result: $backgroundResult');
          }
        } catch (e) {
          LoggingUtils.logWarning('Background location permission request failed: $e');
          // Continue anyway - basic location permission is sufficient
        }
      }

      _locationPermissionRequested = true;
      LoggingUtils.logDebug('Location permissions completed');

      // Notify any waiting callbacks
      for (final callback in _locationPermissionCallbacks) {
        callback();
      }
      _locationPermissionCallbacks.clear();

      return permission;
    } finally {
      _isRequestingPermissions = false;
    }
  }

  /// Check if location permissions are ready to be used
  Future<bool> areLocationPermissionsReady() async {
    if (!_locationPermissionRequested) {
      return false;
    }

    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }

  /// Register a callback to be called when location permissions are ready
  void onLocationPermissionsReady(VoidCallback callback) {
    if (_locationPermissionRequested) {
      // Permissions already requested, call immediately
      callback();
    } else {
      // Add to callback list
      _locationPermissionCallbacks.add(callback);
    }
  }

  /// Reset the coordinator state (useful for testing)
  void reset() {
    _notificationPermissionRequested = false;
    _locationPermissionRequested = false;
    _isRequestingPermissions = false;
    _locationPermissionCallbacks.clear();
  }

  /// Get current permission states for debugging
  Map<String, dynamic> getPermissionStates() {
    return {
      'notificationRequested': _notificationPermissionRequested,
      'locationRequested': _locationPermissionRequested,
      'isRequesting': _isRequestingPermissions,
      'pendingCallbacks': _locationPermissionCallbacks.length,
    };
  }
}