import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'screens/home_screen.dart';
import 'shared/service_manager.dart';
import 'shared/widgets/permission_dialog.dart';
import 'shared/utils/logging_utils.dart';
import 'shared/utils/memory_utils.dart';
import 'shared/utils/image_optimization.dart';
import 'shared/utils/asset_preloader.dart';
import 'shared/utils/image_cache_manager.dart';
import 'shared/utils/platform_optimizer.dart';
import 'shared/mixins/service_access_mixin.dart';
import 'providers/weather_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize only critical components synchronously
  tz.initializeTimeZones();

  // Set fallback timezone immediately, optimize actual timezone in background
  tz.setLocalLocation(tz.getLocation('UTC'));

  // Schedule background initialization for non-critical components
  _scheduleBackgroundInitialization();

  // Note: Service initialization moved to after permission dialog
  // This ensures permissions are requested only after user sees explanation
  runApp(const RideOrDriveApp());
}

/// Schedule non-critical initialization tasks for background execution
void _scheduleBackgroundInitialization() {
  Future.delayed(const Duration(milliseconds: 100), () async {
    try {
      // Set actual local timezone in background
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      final location = tz.getLocation(timeZoneName);
      tz.setLocalLocation(location);
      LoggingUtils.logDebug('Local timezone set to: $timeZoneName');
    } catch (e) {
      LoggingUtils.logError(
          'Failed to set local timezone, using UTC fallback', e);
    }

    // Initialize image optimization and cache management in background
    ImageOptimization.initialize();
    ImageCacheManager.initialize();

    // Initialize platform-specific optimizations in background
    await PlatformOptimizer.initialize();

    LoggingUtils.logDebug('Background initialization completed');
  });
}

/// Initialize scheduled notifications based on user settings
Future<void> _initializeScheduledNotifications() async {
  try {
    final serviceManager = ServiceManager.instance;
    final prefsService = serviceManager.preferencesService;
    final dailyNotificationsEnabled =
        await prefsService.getBool('daily_notifications_enabled') ?? false;

    if (dailyNotificationsEnabled) {
      // Only use scheduled notifications, not background monitoring
      await serviceManager.scheduledNotificationService.scheduleDailyAlarm();
    }
  } catch (e) {
    LoggingUtils.logError('Failed to initialize scheduled notifications', e);
  }
}

class RideOrDriveApp extends StatelessWidget {
  const RideOrDriveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => WeatherProvider(),
      child: MaterialApp(
        title: 'Ride or Drive Weather',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        themeMode: ThemeMode.system,
        home: const PermissionGateScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Screen that handles permission dialog flow before showing main app
class PermissionGateScreen extends StatefulWidget {
  const PermissionGateScreen({super.key});

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen>
    with ServiceAccessMixin, ResourceCleanupMixin {
  bool _isCheckingPermissions = true;
  bool _permissionsGranted = false;
  String _loadingStatus = 'Initializing Ride or Drive Weather...';
  double _loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();

    // Register app-level resources
    registerResource('ServiceManager', 'main_app');

    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      // Step 1: Initialize preferences
      _updateLoadingStatus('Loading preferences...', 0.2);
      await serviceManager.preferencesService.initialize();

      final prefsService = serviceManager.preferencesService;
      final hasShownPermissionDialog =
          await prefsService.getBool('has_shown_permission_dialog') ?? false;

      if (!hasShownPermissionDialog && mounted) {
        // Step 2: Show permission dialog
        _updateLoadingStatus('Requesting permissions...', 0.4);
        final userAccepted = await PermissionDialog.show(context);

        if (userAccepted) {
          // Mark that we've shown the dialog
          await prefsService.setBool('has_shown_permission_dialog', true);

          // Step 3: Initialize services
          _updateLoadingStatus('Initializing services...', 0.6);
          await _initializeServicesAfterPermission();

          _updateLoadingStatus('Ready to launch!', 1.0);
          await Future.delayed(const Duration(milliseconds: 300));

          setState(() {
            _permissionsGranted = true;
            _isCheckingPermissions = false;
          });
        } else {
          // User declined, but proceed anyway (same as accepting)
          await prefsService.setBool('has_shown_permission_dialog', true);
          _updateLoadingStatus('Initializing services...', 0.6);
          await _initializeServicesAfterPermission();

          _updateLoadingStatus('Ready to launch!', 1.0);
          await Future.delayed(const Duration(milliseconds: 300));

          setState(() {
            _permissionsGranted = true;
            _isCheckingPermissions = false;
          });
        }
      } else {
        // Already shown dialog before, initialize services and proceed
        _updateLoadingStatus('Initializing services...', 0.6);
        await _initializeServicesAfterPermission();

        _updateLoadingStatus('Ready to launch!', 1.0);
        await Future.delayed(const Duration(milliseconds: 300));

        setState(() {
          _permissionsGranted = true;
          _isCheckingPermissions = false;
        });
      }
    } catch (e) {
      LoggingUtils.logError('Error checking permissions', e);
      // On error, still try to initialize services and proceed
      _updateLoadingStatus('Initializing services...', 0.6);
      await _initializeServicesAfterPermission();
      setState(() {
        _permissionsGranted = true;
        _isCheckingPermissions = false;
      });
    }
  }

  /// Initialize all services after permission dialog is accepted
  Future<void> _initializeServicesAfterPermission() async {
    // Capture context before async operations
    final capturedContext = context;

    try {
      // Initialize asset preloader (now non-blocking)
      AssetPreloader.initialize(capturedContext);

      // Initialize critical services only
      await serviceManager.initializeAll();

      // Schedule background initialization of notifications
      _scheduleNotificationInitialization();

      // Schedule non-critical asset preloading for next frame
      _scheduleNonCriticalAssetPreloading();
    } catch (e) {
      LoggingUtils.logError('Error initializing services', e);
      // Continue anyway - app should still work with limited functionality
    }
  }

  /// Schedule notification initialization in background
  void _scheduleNotificationInitialization() {
    Future.delayed(const Duration(milliseconds: 200), () async {
      await _initializeScheduledNotifications();
    });
  }

  void _updateLoadingStatus(String status, double progress) {
    if (mounted) {
      setState(() {
        _loadingStatus = status;
        _loadingProgress = progress;
      });
    }
  }

  /// Schedule non-critical asset preloading for the next frame
  void _scheduleNonCriticalAssetPreloading() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AssetPreloader.preloadNonCriticalAssets(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPermissions) {
      return Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    'assets/icon2.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // App Name
              const Text(
                'Ride or Drive Weather',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 60),

              // Loading Progress
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _loadingProgress,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Loading Status Text
                    Text(
                      _loadingStatus,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Progress Percentage
                    Text(
                      '${(_loadingProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_permissionsGranted) {
      return const HomeScreen();
    }

    // Fallback - should not reach here
    return const HomeScreen();
  }
}
