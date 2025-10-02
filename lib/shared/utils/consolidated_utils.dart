/// Consolidated utility classes to reduce code duplication
/// Combines common functionality from various utility classes
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'logging_utils.dart';

/// Consolidated utility class combining common operations
class ConsolidatedUtils {
  // Private constructor to prevent instantiation
  const ConsolidatedUtils._();

  // =============================================================================
  // TIME AND DATE UTILITIES
  // =============================================================================

  /// Format time as HH:MM string with zero padding
  static String formatTime(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Format DateTime as HH:MM string with zero padding
  static String formatDateTime(DateTime dateTime) {
    return formatTime(dateTime.hour, dateTime.minute);
  }

  /// Format time for debug/logging purposes with descriptive prefix
  static String formatTimeForLog(String prefix, int hour, int minute) {
    return '$prefix: ${formatTime(hour, minute)}';
  }

  /// Format DateTime for debug/logging purposes with descriptive prefix
  static String formatDateTimeForLog(String prefix, DateTime dateTime) {
    return formatTimeForLog(prefix, dateTime.hour, dateTime.minute);
  }

  /// Format DateTime as readable string (e.g., "2 minutes ago", "1 hour ago")
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  /// Format duration as human-readable string
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  // =============================================================================
  // STRING UTILITIES
  // =============================================================================

  /// Capitalize first letter of a string
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Convert camelCase to Title Case
  static String camelCaseToTitle(String camelCase) {
    return camelCase
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .trim()
        .split(' ')
        .map(capitalize)
        .join(' ');
  }

  /// Truncate string with ellipsis
  static String truncate(String text, int maxLength,
      {String ellipsis = '...'}) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength - ellipsis.length) + ellipsis;
  }

  /// Check if string is null or empty
  static bool isNullOrEmpty(String? text) {
    return text == null || text.trim().isEmpty;
  }

  /// Check if string is a valid email
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Generate random string of specified length
  static String generateRandomString(int length,
      {bool includeNumbers = true, bool includeSymbols = false}) {
    const letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const symbols = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

    String chars = letters;
    if (includeNumbers) chars += numbers;
    if (includeSymbols) chars += symbols;

    final random = Random();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  // =============================================================================
  // VALIDATION UTILITIES
  // =============================================================================

  /// Validate that a value is not null or empty
  static String? validateRequired(String? value, {String fieldName = 'Field'}) {
    if (isNullOrEmpty(value)) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate email format
  static String? validateEmail(String? value) {
    if (isNullOrEmpty(value)) {
      return 'Email is required';
    }
    if (!isValidEmail(value!)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validate minimum length
  static String? validateMinLength(String? value, int minLength,
      {String fieldName = 'Field'}) {
    if (isNullOrEmpty(value)) {
      return '$fieldName is required';
    }
    if (value!.length < minLength) {
      return '$fieldName must be at least $minLength characters long';
    }
    return null;
  }

  /// Validate numeric input
  static String? validateNumeric(String? value,
      {String fieldName = 'Field', double? min, double? max}) {
    if (isNullOrEmpty(value)) {
      return '$fieldName is required';
    }

    final numValue = double.tryParse(value!);
    if (numValue == null) {
      return '$fieldName must be a valid number';
    }

    if (min != null && numValue < min) {
      return '$fieldName must be at least $min';
    }

    if (max != null && numValue > max) {
      return '$fieldName must be at most $max';
    }

    return null;
  }

  // =============================================================================
  // CONVERSION UTILITIES
  // =============================================================================

  /// Convert temperature from Celsius to Fahrenheit
  static double celsiusToFahrenheit(double celsius) {
    return (celsius * 9 / 5) + 32;
  }

  /// Convert temperature from Fahrenheit to Celsius
  static double fahrenheitToCelsius(double fahrenheit) {
    return (fahrenheit - 32) * 5 / 9;
  }

  /// Convert meters per second to kilometers per hour
  static double mpsToKmh(double mps) {
    return mps * 3.6;
  }

  /// Convert kilometers per hour to meters per second
  static double kmhToMps(double kmh) {
    return kmh / 3.6;
  }

  /// Convert bytes to human-readable format
  static String formatBytes(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    if (bytes == 0) return '0 B';

    final i = (log(bytes) / log(1024)).floor();
    final size = bytes / pow(1024, i);

    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Convert milliseconds to Duration
  static Duration millisecondsToDuration(int milliseconds) {
    return Duration(milliseconds: milliseconds);
  }

  /// Convert Duration to milliseconds
  static int durationToMilliseconds(Duration duration) {
    return duration.inMilliseconds;
  }

  // =============================================================================
  // COLLECTION UTILITIES
  // =============================================================================

  /// Check if list is null or empty
  static bool isListNullOrEmpty<T>(List<T>? list) {
    return list == null || list.isEmpty;
  }

  /// Get safe element from list at index
  static T? safeGet<T>(List<T>? list, int index) {
    if (isListNullOrEmpty(list) || index < 0 || index >= list!.length) {
      return null;
    }
    return list[index];
  }

  /// Chunk list into smaller lists of specified size
  static List<List<T>> chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (int i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, min(i + chunkSize, list.length)));
    }
    return chunks;
  }

  /// Remove duplicates from list while preserving order
  static List<T> removeDuplicates<T>(List<T> list) {
    final seen = <T>{};
    return list.where((item) => seen.add(item)).toList();
  }

  /// Find common elements between two lists
  static List<T> findCommon<T>(List<T> list1, List<T> list2) {
    return list1.where((item) => list2.contains(item)).toList();
  }

  // =============================================================================
  // MATH UTILITIES
  // =============================================================================

  /// Clamp value between min and max
  static T clamp<T extends num>(T value, T min, T max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Calculate percentage
  static double percentage(num value, num total) {
    if (total == 0) return 0;
    return (value / total) * 100;
  }

  /// Round to specified decimal places
  static double roundToDecimalPlaces(double value, int decimalPlaces) {
    final factor = pow(10, decimalPlaces);
    return (value * factor).round() / factor;
  }

  /// Check if number is within range (inclusive)
  static bool isInRange(num value, num min, num max) {
    return value >= min && value <= max;
  }

  /// Generate random number within range
  static int randomInRange(int min, int max) {
    return Random().nextInt(max - min + 1) + min;
  }

  // =============================================================================
  // ERROR HANDLING UTILITIES
  // =============================================================================

  /// Execute operation with error handling and logging
  static Future<T?> executeWithErrorHandling<T>({
    required Future<T> Function() operation,
    required String operationName,
    Function(String)? onError,
    Function(String)? onSuccess,
    bool logStackTrace = false,
  }) async {
    try {
      final result = await operation();
      if (onSuccess != null) {
        onSuccess('$operationName completed successfully');
      }
      return result;
    } catch (e, stackTrace) {
      final errorMessage = '$operationName failed: $e';

      LoggingUtils.logError(errorMessage, logStackTrace ? stackTrace : null);

      if (onError != null) {
        onError(errorMessage);
      }

      return null;
    }
  }

  /// Execute sync operation with error handling
  static T? executeSyncWithErrorHandling<T>({
    required T Function() operation,
    required String operationName,
    Function(String)? onError,
    Function(String)? onSuccess,
  }) {
    try {
      final result = operation();
      if (onSuccess != null) {
        onSuccess('$operationName completed successfully');
      }
      return result;
    } catch (e) {
      final errorMessage = '$operationName failed: $e';

      LoggingUtils.logError(errorMessage);

      if (onError != null) {
        onError(errorMessage);
      }

      return null;
    }
  }

  // =============================================================================
  // ASYNC UTILITIES
  // =============================================================================

  /// Execute operation with retry logic
  static Future<T?> executeWithRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    String? operationName,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxRetries) {
      try {
        final result = await operation();
        if (operationName != null && attempt > 0) {
          LoggingUtils.logDebug(
              '$operationName succeeded on attempt ${attempt + 1}');
        }
        return result;
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          if (operationName != null) {
            LoggingUtils.logError(
                '$operationName failed after $maxRetries attempts', e);
          }
          rethrow;
        }

        if (operationName != null) {
          LoggingUtils.logWarning(
              '$operationName failed on attempt $attempt, retrying in ${delay.inMilliseconds}ms');
        }

        await Future.delayed(delay);
        delay = Duration(
            milliseconds: (delay.inMilliseconds * backoffMultiplier).round());
      }
    }

    return null;
  }

  /// Execute operation with timeout
  static Future<T?> executeWithTimeout<T>({
    required Future<T> Function() operation,
    required Duration timeout,
    String? operationName,
  }) async {
    try {
      return await operation().timeout(timeout);
    } on TimeoutException {
      if (operationName != null) {
        LoggingUtils.logError(
            '$operationName timed out after ${timeout.inMilliseconds}ms');
      }
      return null;
    } catch (e) {
      if (operationName != null) {
        LoggingUtils.logError('$operationName failed', e);
      }
      return null;
    }
  }

  // =============================================================================
  // DEBOUNCING AND THROTTLING
  // =============================================================================

  static final Map<String, Timer> _debounceTimers = {};
  static final Map<String, DateTime> _throttleTimestamps = {};

  /// Debounce function execution
  static void debounce(String key, Duration delay, VoidCallback callback) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(delay, () {
      callback();
      _debounceTimers.remove(key);
    });
  }

  /// Throttle function execution
  static void throttle(String key, Duration interval, VoidCallback callback) {
    final now = DateTime.now();
    final lastExecution = _throttleTimestamps[key];

    if (lastExecution == null || now.difference(lastExecution) >= interval) {
      _throttleTimestamps[key] = now;
      callback();
    }
  }

  /// Clear all debounce timers
  static void clearDebounceTimers() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }

  /// Clear throttle timestamps
  static void clearThrottleTimestamps() {
    _throttleTimestamps.clear();
  }

  // =============================================================================
  // PLATFORM UTILITIES
  // =============================================================================

  /// Check if running on mobile platform
  static bool get isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;



  /// Check if running in debug mode
  static bool get isDebug => kDebugMode;

  /// Check if running in release mode
  static bool get isRelease => kReleaseMode;

  /// Check if running in profile mode
  static bool get isProfile => kProfileMode;

  // =============================================================================
  // CLEANUP UTILITIES
  // =============================================================================

  /// Dispose all internal resources
  static void dispose() {
    clearDebounceTimers();
    clearThrottleTimestamps();
    LoggingUtils.logDebug('ConsolidatedUtils disposed');
  }
}

/// Enhanced UI utilities combining SnackBar and Navigation functionality
class EnhancedUIUtils {
  // Private constructor to prevent instantiation
  const EnhancedUIUtils._();

  // =============================================================================
  // SNACKBAR UTILITIES
  // =============================================================================

  /// Show error snackbar with consistent styling
  static void showError(BuildContext context, String message,
      {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 3,
        duration: duration ?? const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white70,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  /// Show success snackbar with consistent styling
  static void showSuccess(BuildContext context, String message,
      {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 3,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Show info snackbar with consistent styling
  static void showInfo(BuildContext context, String message,
      {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 3,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Show warning snackbar with consistent styling
  static void showWarning(BuildContext context, String message,
      {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 3,
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }

  // =============================================================================
  // NAVIGATION UTILITIES
  // =============================================================================

  /// Navigate to screen with slide transition
  static Future<T?> pushScreen<T>(BuildContext context, Widget screen,
      {bool maintainState = true}) {
    return Navigator.push<T>(
      context,
      PageRouteBuilder<T>(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;

          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
        maintainState: maintainState,
      ),
    );
  }

  /// Navigate to screen replacing current screen
  static Future<T?> pushReplacementScreen<T, TO>(
      BuildContext context, Widget screen) {
    return Navigator.pushReplacement<T, TO>(
      context,
      PageRouteBuilder<T>(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// Navigate to screen and clear all previous screens
  static Future<T?> pushAndClearStack<T>(BuildContext context, Widget screen) {
    return Navigator.pushAndRemoveUntil<T>(
      context,
      PageRouteBuilder<T>(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  /// Pop screen with result
  static void popScreen<T>(BuildContext context, [T? result]) {
    Navigator.pop<T>(context, result);
  }

  /// Pop until specific screen
  static void popUntil(
      BuildContext context, bool Function(Route<dynamic>) predicate) {
    Navigator.popUntil(context, predicate);
  }

  /// Check if can pop
  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }

  // =============================================================================
  // DIALOG UTILITIES
  // =============================================================================

  /// Show confirmation dialog
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDangerous = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelText),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: isDangerous
                    ? TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error)
                    : null,
                child: Text(confirmText),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Show loading dialog
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message),
            ],
          ],
        ),
      ),
    );
  }

  /// Hide loading dialog
  static void hideLoadingDialog(BuildContext context) {
    Navigator.pop(context);
  }

  // =============================================================================
  // THEME UTILITIES
  // =============================================================================

  /// Get current theme brightness
  static Brightness getCurrentBrightness(BuildContext context) {
    return Theme.of(context).brightness;
  }

  /// Check if current theme is dark
  static bool isDarkTheme(BuildContext context) {
    return getCurrentBrightness(context) == Brightness.dark;
  }

  /// Get appropriate text color for current theme
  static Color getTextColor(BuildContext context) {
    return Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
  }

  /// Get appropriate background color for current theme
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }
}

/// Consolidated mixin for common functionality
mixin ConsolidatedMixin {
  /// Format time with consolidated utils
  String formatTime(int hour, int minute) =>
      ConsolidatedUtils.formatTime(hour, minute);

  /// Format DateTime with consolidated utils
  String formatDateTime(DateTime dateTime) =>
      ConsolidatedUtils.formatDateTime(dateTime);

  /// Format relative time
  String formatRelativeTime(DateTime dateTime) =>
      ConsolidatedUtils.formatRelativeTime(dateTime);

  /// Validate required field
  String? validateRequired(String? value, {String fieldName = 'Field'}) {
    return ConsolidatedUtils.validateRequired(value, fieldName: fieldName);
  }

  /// Validate email
  String? validateEmail(String? value) =>
      ConsolidatedUtils.validateEmail(value);

  /// Execute with error handling
  Future<T?> executeWithErrorHandling<T>({
    required Future<T> Function() operation,
    required String operationName,
    Function(String)? onError,
    Function(String)? onSuccess,
    bool logStackTrace = false,
  }) {
    return ConsolidatedUtils.executeWithErrorHandling<T>(
      operation: operation,
      operationName: operationName,
      onError: onError,
      onSuccess: onSuccess,
      logStackTrace: logStackTrace,
    );
  }

  /// Execute with retry
  Future<T?> executeWithRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    String? operationName,
  }) {
    return ConsolidatedUtils.executeWithRetry<T>(
      operation: operation,
      maxRetries: maxRetries,
      initialDelay: initialDelay,
      backoffMultiplier: backoffMultiplier,
      operationName: operationName,
    );
  }

  /// Debounce function execution
  void debounce(String key, Duration delay, VoidCallback callback) {
    ConsolidatedUtils.debounce(key, delay, callback);
  }

  /// Throttle function execution
  void throttle(String key, Duration interval, VoidCallback callback) {
    ConsolidatedUtils.throttle(key, interval, callback);
  }

  /// Show error snackbar
  void showError(BuildContext context, String message, {Duration? duration}) {
    EnhancedUIUtils.showError(context, message, duration: duration);
  }

  /// Show success snackbar
  void showSuccess(BuildContext context, String message, {Duration? duration}) {
    EnhancedUIUtils.showSuccess(context, message, duration: duration);
  }

  /// Show info snackbar
  void showInfo(BuildContext context, String message, {Duration? duration}) {
    EnhancedUIUtils.showInfo(context, message, duration: duration);
  }

  /// Navigate to screen
  Future<T?> pushScreen<T>(BuildContext context, Widget screen,
      {bool maintainState = true}) {
    return EnhancedUIUtils.pushScreen<T>(context, screen,
        maintainState: maintainState);
  }

  /// Show confirmation dialog
  Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDangerous = false,
  }) {
    return EnhancedUIUtils.showConfirmationDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDangerous: isDangerous,
    );
  }
}
