class TradeStatus {
  static const String filled = 'FILLED';
  static const String failed = 'FAILED';
}

class TradeItem {
  final String id;
  final DateTime timestamp;
  final String side; // 'BUY' or 'SELL'
  final String symbol;
  final double executedQty;
  final double averagePrice;
  final double signalPrice;
  final double signalConfidence;
  final String status; // 'FILLED' or 'FAILED'
  final String? errorMessage;
  final String signalId;

  TradeItem({
    required this.id,
    required this.timestamp,
    required this.side,
    required this.symbol,
    required this.executedQty,
    required this.averagePrice,
    required this.signalPrice,
    required this.signalConfidence,
    required this.status,
    this.errorMessage,
    required this.signalId,
  });

  bool get isBuy => side.toUpperCase() == 'BUY';
  bool get isFilled => status == TradeStatus.filled;

  /// Price slippage: difference between execution and signal price
  double get slippage => averagePrice - signalPrice;
  double get slippagePct => signalPrice > 0 ? (slippage / signalPrice) * 100 : 0;

  /// Notional value of the trade
  double get notionalValue => executedQty * averagePrice;

  factory TradeItem.fromJson(Map<String, dynamic> json) {
    return TradeItem(
      id: json['_id']?.toString() ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      side: json['side'] ?? json['signal_type'] ?? 'BUY',
      symbol: json['symbol'] ?? 'BTCUSDT',
      executedQty: (json['executed_qty'] as num?)?.toDouble() ?? 0.0,
      averagePrice: (json['average_price'] as num?)?.toDouble() ?? 0.0,
      signalPrice: (json['signal_price'] as num?)?.toDouble() ?? 0.0,
      signalConfidence: (json['signal_confidence'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? TradeStatus.failed,
      errorMessage: json['error'],
      signalId: json['signal_id']?.toString() ?? '',
    );
  }
}
