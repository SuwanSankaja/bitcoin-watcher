/// Portfolio summary aggregated from all BUY trades
class PortfolioSummary {
  final double totalBtcAccumulated;
  final double totalUsdtSpent;
  final double averageCostBasis;
  final double currentBtcPrice;
  final double currentValue;
  final double unrealizedPnlPercent;
  final int tradeCount;
  final List<TradeHistoryPoint> tradeHistory;

  PortfolioSummary({
    required this.totalBtcAccumulated,
    required this.totalUsdtSpent,
    required this.averageCostBasis,
    required this.currentBtcPrice,
    required this.currentValue,
    required this.unrealizedPnlPercent,
    required this.tradeCount,
    required this.tradeHistory,
  });

  factory PortfolioSummary.fromJson(Map<String, dynamic> json) {
    return PortfolioSummary(
      totalBtcAccumulated:
          (json['total_btc_accumulated'] as num?)?.toDouble() ?? 0.0,
      totalUsdtSpent: (json['total_usdt_spent'] as num?)?.toDouble() ?? 0.0,
      averageCostBasis: (json['average_cost_basis'] as num?)?.toDouble() ?? 0.0,
      currentBtcPrice: (json['current_btc_price'] as num?)?.toDouble() ?? 0.0,
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0.0,
      unrealizedPnlPercent:
          (json['unrealized_pnl_percent'] as num?)?.toDouble() ?? 0.0,
      tradeCount: json['trade_count'] as int? ?? 0,
      tradeHistory: (json['trade_history'] as List<dynamic>? ?? [])
          .map((e) => TradeHistoryPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isProfit => unrealizedPnlPercent >= 0;
  bool get isEmpty => totalBtcAccumulated == 0;
}

class TradeHistoryPoint {
  final DateTime timestamp;
  final double btcAcquired;
  final double cumulativeBtc;
  final double averagePrice;
  final double? accumulationScore;

  TradeHistoryPoint({
    required this.timestamp,
    required this.btcAcquired,
    required this.cumulativeBtc,
    required this.averagePrice,
    this.accumulationScore,
  });

  factory TradeHistoryPoint.fromJson(Map<String, dynamic> json) {
    return TradeHistoryPoint(
      timestamp: DateTime.parse(json['timestamp']),
      btcAcquired: (json['btc_acquired'] as num?)?.toDouble() ?? 0.0,
      cumulativeBtc: (json['cumulative_btc'] as num?)?.toDouble() ?? 0.0,
      averagePrice: (json['average_price'] as num?)?.toDouble() ?? 0.0,
      accumulationScore: (json['accumulation_score'] as num?)?.toDouble(),
    );
  }
}
