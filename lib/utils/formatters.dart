import 'package:intl/intl.dart';

class Formatters {
  // Format price as USD
  static String formatPrice(double price) {
    final formatter = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );
    return formatter.format(price);
  }

  // Format large numbers with K, M suffixes
  static String formatCompact(double value) {
    final formatter = NumberFormat.compact();
    return formatter.format(value);
  }

  // Format percentage
  static String formatPercentage(double value, {int decimals = 1}) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  // Format date and time
  static String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final formatter = DateFormat('MMM dd, yyyy');
      return formatter.format(dateTime);
    }
  }

  // Format full date time
  static String formatFullDateTime(DateTime dateTime) {
    final formatter = DateFormat('MMM dd, yyyy • hh:mm a');
    return formatter.format(dateTime);
  }

  // Format time only
  static String formatTime(DateTime dateTime) {
    final formatter = DateFormat('hh:mm a');
    return formatter.format(dateTime);
  }
}
