import '../models/models.dart';
import '../utils/api_config.dart';
import 'api_client.dart';

class BitcoinService {
  final ApiClient _apiClient;

  BitcoinService({ApiClient? apiClient})
      : _apiClient = apiClient ??
            ApiClient(
              baseUrl: ApiConfig.baseUrl,
              timeout: ApiConfig.timeout,
              headers: ApiConfig.headers,
            );

  /// Fetch the current BTC price and signal
  Future<Map<String, dynamic>> getCurrentPrice() async {
    try {
      final response = await _apiClient.get(ApiConfig.currentPriceEndpoint);
      return {
        'price': BtcPrice.fromJson(response['price']),
        'signal': Signal.fromJson(response['signal']),
      };
    } catch (e) {
      throw ApiException('Failed to fetch current price: $e');
    }
  }

  /// Fetch price history for chart (last 24 hours)
  Future<List<BtcPrice>> getPriceHistory({int hours = 24}) async {
    try {
      final response = await _apiClient.get(
        '${ApiConfig.priceHistoryEndpoint}?hours=$hours',
      );
      final List<dynamic> prices = response['prices'] ?? [];
      return prices.map((json) => BtcPrice.fromJson(json)).toList();
    } catch (e) {
      throw ApiException('Failed to fetch price history: $e');
    }
  }

  /// Fetch signal/notification history
  Future<List<NotificationItem>> getSignalHistory({int limit = 50}) async {
    try {
      final response = await _apiClient.get(
        '${ApiConfig.signalHistoryEndpoint}?limit=$limit',
      );
      final List<dynamic> notifications = response['notifications'] ?? [];
      return notifications
          .map((json) => NotificationItem.fromJson(json))
          .toList();
    } catch (e) {
      throw ApiException('Failed to fetch signal history: $e');
    }
  }

  /// Get user settings
  Future<AppSettings> getSettings() async {
    try {
      final response = await _apiClient.get(ApiConfig.settingsEndpoint);
      return AppSettings.fromJson(response['settings']);
    } catch (e) {
      // Return default settings if fetch fails
      return AppSettings();
    }
  }

  /// Update user settings
  Future<void> updateSettings(AppSettings settings) async {
    try {
      await _apiClient.post(
        ApiConfig.settingsEndpoint,
        settings.toJson(),
      );
    } catch (e) {
      throw ApiException('Failed to update settings: $e');
    }
  }
}
