import 'signal.dart';

class NotificationItem {
  final String id;
  final DateTime timestamp;
  final String signalId;
  final String title;
  final String message;
  final SignalType signalType;
  final double price;

  NotificationItem({
    required this.id,
    required this.timestamp,
    required this.signalId,
    required this.title,
    required this.message,
    required this.signalType,
    required this.price,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      signalId: json['signal_id']?.toString() ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      signalType: SignalType.fromString(json['signal_type'] ?? 'HOLD'),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'signal_id': signalId,
      'title': title,
      'message': message,
      'signal_type': signalType.displayName,
      'price': price,
    };
  }

  @override
  String toString() => 'NotificationItem(title: $title, type: ${signalType.displayName})';
}
