class ApiConfig {
  // Replace this with your actual API Gateway URL after deployment
  static const String baseUrl = 'https://25sm56ym2c.execute-api.us-east-1.amazonaws.com/prod';
  
  // API Endpoints
  static const String currentPriceEndpoint = '/currentPrice';
  static const String signalHistoryEndpoint = '/signalHistory';
  static const String settingsEndpoint = '/settings';
  static const String priceHistoryEndpoint = '/priceHistory';
  
  // Request timeout
  static const Duration timeout = Duration(seconds: 30);
  
  // Headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
