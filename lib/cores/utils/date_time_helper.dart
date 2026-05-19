import 'package:intl/intl.dart';

class DateTimeHelper {
  static Map<String, int> weekOrder = {
    'Mon': 0,
    'Tue': 1,
    'Wed': 2,
    'Thu': 3,
    'Fri': 4,
    'Sat': 5,
    'Sun': 6,
  };

  static Map<int, String> regularWeek = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  static const Map<int, String> regularMonths = {
    1: 'January',
    2: 'February',
    3: 'March',
    4: 'April',
    5: 'May',
    6: 'June',
    7: 'July',
    8: 'August',
    9: 'September',
    10: 'October',
    11: 'November',
    12: 'December',
  };
  static String formatDateMonthYear(DateTime date) =>
      DateFormat('dd/MM/yyyy').format(date);

  static String formatDateMonthClock(DateTime date) =>
      DateFormat('d/M, HH.mm').format(date);

  static String formatChatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    // Today — show time
    if (diff.inDays == 0 && now.day == dateTime.day) {
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    }

    // Yesterday
    if (diff.inDays == 1 || (diff.inDays == 0 && now.day != dateTime.day)) {
      return 'Yesterday';
    }

    // Within this week — show day name
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    }

    // Older — show date
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}';
  }
}
