enum SignalType {
  buy,
  sell,
  hold;

  String get displayName {
    switch (this) {
      case SignalType.buy:
        return 'BUY';
      case SignalType.sell:
        return 'SELL';
      case SignalType.hold:
        return 'HOLD';
    }
  }

  static SignalType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'BUY':
        return SignalType.buy;
      case 'SELL':
        return SignalType.sell;
      case 'HOLD':
        return SignalType.hold;
      default:
        return SignalType.hold;
    }
  }
}

class Signal {
  final String id;
  final DateTime timestamp;
  final SignalType type;
  final double price;
  final double confidence;

  Signal({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.price,
    required this.confidence,
  });

  factory Signal.fromJson(Map<String, dynamic> json) {
    return Signal(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      type: SignalType.fromString(json['type']),
      price: (json['price'] as num).toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.displayName,
      'price': price,
      'confidence': confidence,
    };
  }

  @override
  String toString() =>
      'Signal(type: ${type.displayName}, price: \$$price, confidence: ${confidence.toStringAsFixed(1)}%)';
}
