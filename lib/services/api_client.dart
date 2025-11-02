import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message ${statusCode != null ? '(Status: $statusCode)' : ''}';
}

class ApiClient {
  final String baseUrl;
  final Duration timeout;
  final Map<String, String> headers;

  ApiClient({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 30),
    Map<String, String>? headers,
  }) : headers = headers ?? {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await http.get(url, headers: headers).timeout(timeout);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on HttpException {
      throw ApiException('HTTP error occurred');
    } on FormatException {
      throw ApiException('Invalid response format');
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      ).timeout(timeout);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on HttpException {
      throw ApiException('HTTP error occurred');
    } on FormatException {
      throw ApiException('Invalid response format');
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw ApiException('Failed to parse response');
      }
    } else if (response.statusCode == 404) {
      throw ApiException('Endpoint not found', response.statusCode);
    } else if (response.statusCode == 500) {
      throw ApiException('Server error', response.statusCode);
    } else {
      throw ApiException(
        'Request failed with status: ${response.statusCode}',
        response.statusCode,
      );
    }
  }
}
