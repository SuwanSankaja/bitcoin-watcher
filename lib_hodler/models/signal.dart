// Hodler edition: extended Signal model with accumulation score fields
enum SignalType {
  buy,
  hold;

  String get displayName {
    switch (this) {
      case SignalType.buy:
        return 'BUY';
      case SignalType.hold:
        return 'HOLD';
    }
  }

  static SignalType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'BUY':
        return SignalType.buy;
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
  // Hodler-specific fields
  final double? accumulationScore;
  final bool? buyZone;
  final double? rsi;
  final double? bbLower;
  final int? fearGreedIndex;
  final String? fearGreedLabel;
  final double? dipDepth;

  Signal({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.price,
    required this.confidence,
    this.accumulationScore,
    this.buyZone,
    this.rsi,
    this.bbLower,
    this.fearGreedIndex,
    this.fearGreedLabel,
    this.dipDepth,
  });

  factory Signal.fromJson(Map<String, dynamic> json) {
    return Signal(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      type: SignalType.fromString(json['type'] ?? 'HOLD'),
      price: (json['price'] as num).toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      accumulationScore: (json['accumulation_score'] as num?)?.toDouble(),
      buyZone: json['buy_zone'] as bool?,
      rsi: (json['rsi'] as num?)?.toDouble(),
      bbLower: (json['bb_lower'] as num?)?.toDouble(),
      fearGreedIndex: json['fear_greed_index'] as int?,
      fearGreedLabel: json['fear_greed_label'] as String?,
      dipDepth: (json['dip_depth'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.displayName,
      'price': price,
      'confidence': confidence,
      'accumulation_score': accumulationScore,
      'buy_zone': buyZone,
      'rsi': rsi,
      'bb_lower': bbLower,
      'fear_greed_index': fearGreedIndex,
      'fear_greed_label': fearGreedLabel,
      'dip_depth': dipDepth,
    };
  }

  @override
  String toString() => 'Signal(type: ${type.displayName}, score: '
      '${accumulationScore?.toStringAsFixed(1) ?? 'N/A'}/100, '
      'price: \$$price)';
}
