import 'package:intl/intl.dart';

/// Date/time formatting utilities.
class DateFormatter {
  DateFormatter._();

  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final _timeFormat = DateFormat('hh:mm a');
  static final _shortDate = DateFormat('dd/MM/yy');
  static final _monthDay = DateFormat('dd MMM');
  static final _dayOfWeek = DateFormat('EEE');

  /// "19 Sep 2026"
  static String formatDate(DateTime date) => _dateFormat.format(date);

  /// "19 Sep 2026, 02:30 PM"
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);

  /// "02:30 PM"
  static String formatTime(DateTime date) => _timeFormat.format(date);

  /// "19/09/26"
  static String formatShortDate(DateTime date) => _shortDate.format(date);

  /// "19 Sep"
  static String formatMonthDay(DateTime date) => _monthDay.format(date);

  /// "Mon"
  static String formatDayOfWeek(DateTime date) => _dayOfWeek.format(date);

  /// "2 minutes ago", "1 hour ago", "3 days ago"
  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return formatDate(date);
    }
  }

  /// "Good Morning", "Good Afternoon", "Good Evening"
  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}
