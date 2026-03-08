// Hodler api_config — uses HODLER_API_BASE_URL dart-define,
// falls back to the same prod Gateway (override when running hodler variant)
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'HODLER_API_BASE_URL',
    defaultValue:
        'https://o9tic8ti7h.execute-api.ap-northeast-1.amazonaws.com/prod',
  );

  static const String currentPriceEndpoint = '/currentPrice';
  static const String signalHistoryEndpoint = '/signalHistory';
  static const String tradesHistoryEndpoint = '/tradesHistory';
  static const String settingsEndpoint = '/settings';
  static const String priceHistoryEndpoint = '/priceHistory';
  static const String portfolioEndpoint = '/portfolio';

  static const Duration timeout = Duration(seconds: 30);

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
