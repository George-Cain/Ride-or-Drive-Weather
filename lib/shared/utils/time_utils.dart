/// Time formatting utilities
/// Provides consistent time formatting patterns across the application
library;

/// Utility class for time formatting operations
class TimeUtils {
  // Private constructor to prevent instantiation
  const TimeUtils._();

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
}