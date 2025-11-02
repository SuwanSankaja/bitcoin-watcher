class AppSettings {
  final bool notificationsEnabled;
  final double buyThreshold;
  final double sellThreshold;
  final int shortMaPeriod;
  final int longMaPeriod;

  AppSettings({
    this.notificationsEnabled = true,
    this.buyThreshold = 0.005,
    this.sellThreshold = 0.005,
    this.shortMaPeriod = 7,
    this.longMaPeriod = 21,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      notificationsEnabled: json['notifications_enabled'] ?? true,
      buyThreshold: (json['buy_threshold'] as num?)?.toDouble() ?? 0.005,
      sellThreshold: (json['sell_threshold'] as num?)?.toDouble() ?? 0.005,
      shortMaPeriod: json['short_ma_period'] ?? 7,
      longMaPeriod: json['long_ma_period'] ?? 21,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notifications_enabled': notificationsEnabled,
      'buy_threshold': buyThreshold,
      'sell_threshold': sellThreshold,
      'short_ma_period': shortMaPeriod,
      'long_ma_period': longMaPeriod,
    };
  }

  AppSettings copyWith({
    bool? notificationsEnabled,
    double? buyThreshold,
    double? sellThreshold,
    int? shortMaPeriod,
    int? longMaPeriod,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      buyThreshold: buyThreshold ?? this.buyThreshold,
      sellThreshold: sellThreshold ?? this.sellThreshold,
      shortMaPeriod: shortMaPeriod ?? this.shortMaPeriod,
      longMaPeriod: longMaPeriod ?? this.longMaPeriod,
    );
  }
}
