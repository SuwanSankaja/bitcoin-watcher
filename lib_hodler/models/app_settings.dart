class AppSettings {
  final bool notificationsEnabled;
  final double buyThreshold;
  final int shortMaPeriod;
  final int longMaPeriod;
  final int rsiPeriod;
  final int rsiOversold;
  final int rsiOverbought;
  final int bbPeriod;
  final double bbStdDev;
  // DCA / Accumulation settings
  final int minScoreThreshold;
  final int lookbackHours;
  final bool tradingEnabled;
  final String tradingMode;
  final double tradeAmountUsdt;
  final double dcaScaleFactor;
  final double maxSingleTradeUsdt;

  AppSettings({
    this.notificationsEnabled = true,
    this.buyThreshold = 0.001,
    this.shortMaPeriod = 7,
    this.longMaPeriod = 25,
    this.rsiPeriod = 14,
    this.rsiOversold = 30,
    this.rsiOverbought = 70,
    this.bbPeriod = 20,
    this.bbStdDev = 2.0,
    this.minScoreThreshold = 60,
    this.lookbackHours = 4,
    this.tradingEnabled = false,
    this.tradingMode = 'testnet',
    this.tradeAmountUsdt = 20,
    this.dcaScaleFactor = 1.5,
    this.maxSingleTradeUsdt = 200,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      notificationsEnabled: json['notifications_enabled'] ?? true,
      buyThreshold: (json['buy_threshold'] as num?)?.toDouble() ?? 0.001,
      shortMaPeriod: json['short_ma_period'] ?? 7,
      longMaPeriod: json['long_ma_period'] ?? 25,
      rsiPeriod: json['rsi_period'] ?? 14,
      rsiOversold: json['rsi_oversold'] ?? 30,
      rsiOverbought: json['rsi_overbought'] ?? 70,
      bbPeriod: json['bb_period'] ?? 20,
      bbStdDev: (json['bb_std_dev'] as num?)?.toDouble() ?? 2.0,
      minScoreThreshold: json['min_score_threshold'] ?? 60,
      lookbackHours: json['lookback_hours'] ?? 4,
      tradingEnabled: json['trading_enabled'] ?? false,
      tradingMode: json['trading_mode'] ?? 'testnet',
      tradeAmountUsdt: (json['trade_amount_usdt'] as num?)?.toDouble() ?? 20.0,
      dcaScaleFactor: (json['dca_scale_factor'] as num?)?.toDouble() ?? 1.5,
      maxSingleTradeUsdt:
          (json['max_single_trade_usdt'] as num?)?.toDouble() ?? 200.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notifications_enabled': notificationsEnabled,
      'buy_threshold': buyThreshold,
      'short_ma_period': shortMaPeriod,
      'long_ma_period': longMaPeriod,
      'rsi_period': rsiPeriod,
      'rsi_oversold': rsiOversold,
      'rsi_overbought': rsiOverbought,
      'bb_period': bbPeriod,
      'bb_std_dev': bbStdDev,
      'min_score_threshold': minScoreThreshold,
      'lookback_hours': lookbackHours,
      'trading_enabled': tradingEnabled,
      'trading_mode': tradingMode,
      'trade_amount_usdt': tradeAmountUsdt,
      'dca_scale_factor': dcaScaleFactor,
      'max_single_trade_usdt': maxSingleTradeUsdt,
    };
  }

  AppSettings copyWith({
    bool? notificationsEnabled,
    double? buyThreshold,
    int? shortMaPeriod,
    int? longMaPeriod,
    int? rsiPeriod,
    int? rsiOversold,
    int? rsiOverbought,
    int? bbPeriod,
    double? bbStdDev,
    int? minScoreThreshold,
    int? lookbackHours,
    bool? tradingEnabled,
    String? tradingMode,
    double? tradeAmountUsdt,
    double? dcaScaleFactor,
    double? maxSingleTradeUsdt,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      buyThreshold: buyThreshold ?? this.buyThreshold,
      shortMaPeriod: shortMaPeriod ?? this.shortMaPeriod,
      longMaPeriod: longMaPeriod ?? this.longMaPeriod,
      rsiPeriod: rsiPeriod ?? this.rsiPeriod,
      rsiOversold: rsiOversold ?? this.rsiOversold,
      rsiOverbought: rsiOverbought ?? this.rsiOverbought,
      bbPeriod: bbPeriod ?? this.bbPeriod,
      bbStdDev: bbStdDev ?? this.bbStdDev,
      minScoreThreshold: minScoreThreshold ?? this.minScoreThreshold,
      lookbackHours: lookbackHours ?? this.lookbackHours,
      tradingEnabled: tradingEnabled ?? this.tradingEnabled,
      tradingMode: tradingMode ?? this.tradingMode,
      tradeAmountUsdt: tradeAmountUsdt ?? this.tradeAmountUsdt,
      dcaScaleFactor: dcaScaleFactor ?? this.dcaScaleFactor,
      maxSingleTradeUsdt: maxSingleTradeUsdt ?? this.maxSingleTradeUsdt,
    );
  }
}
