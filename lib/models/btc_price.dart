class BtcPrice {
  final DateTime timestamp;
  final double price;

  BtcPrice({
    required this.timestamp,
    required this.price,
  });

  factory BtcPrice.fromJson(Map<String, dynamic> json) {
    return BtcPrice(
      timestamp: DateTime.parse(json['timestamp']),
      price: (json['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'price': price,
    };
  }

  @override
  String toString() => 'BtcPrice(timestamp: $timestamp, price: \$$price)';
}
