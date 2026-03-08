class TradeStatus {
  static const String filled = 'FILLED';
  static const String failed = 'FAILED';
}

class TradeItem {
  final String id;
  final DateTime timestamp;
  final String side;
  final String symbol;
  final double executedQty;
  final double averagePrice;
  final double signalPrice;
  final double signalConfidence;
  final String status;
  final String? errorMessage;
  final String signalId;
  final double? btcBalanceAfter;
  // Hodler-specific
  final double? accumulationScore;
  final double? usdtSpent;

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
    this.btcBalanceAfter,
    this.accumulationScore,
    this.usdtSpent,
  });

  bool get isBuy => side.toUpperCase() == 'BUY';
  bool get isFilled => status == TradeStatus.filled;

  double get slippage => averagePrice - signalPrice;
  double get slippagePct =>
      signalPrice > 0 ? (slippage / signalPrice) * 100 : 0;
  double get notionalValue => executedQty * averagePrice;

  factory TradeItem.fromJson(Map<String, dynamic> json) {
    return TradeItem(
      id: json['_id']?.toString() ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      side: json['side'] ?? 'BUY',
      symbol: json['symbol'] ?? 'BTCUSDT',
      executedQty: (json['executed_qty'] as num?)?.toDouble() ?? 0.0,
      averagePrice: (json['average_price'] as num?)?.toDouble() ?? 0.0,
      signalPrice: (json['signal_price'] as num?)?.toDouble() ?? 0.0,
      signalConfidence: (json['signal_confidence'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? TradeStatus.failed,
      errorMessage: json['error'],
      signalId: json['signal_id']?.toString() ?? '',
      btcBalanceAfter: (json['btc_balance_after'] as num?)?.toDouble(),
      accumulationScore: (json['accumulation_score'] as num?)?.toDouble(),
      usdtSpent: (json['usdt_spent'] as num?)?.toDouble(),
    );
  }
}
