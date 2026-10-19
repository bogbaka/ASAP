import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class AuthService {
  AuthService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Uri _endpoint(String path) {
    return Uri.parse('${ApiConfig.baseUrl}$path');
  }

  Future<Map<String, dynamic>> requestOtp({
    required String phoneNumber,
  }) async {
    final response = await _client
        .post(
          _endpoint('/auth/otp/request'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone_number': phoneNumber,
          }),
        )
        .timeout(ApiConfig.connectionTimeout);

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phoneNumber,
    required String code,
  }) async {
    final response = await _client
        .post(
          _endpoint('/auth/otp/verify'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone_number': phoneNumber,
            'code': code,
          }),
        )
        .timeout(ApiConfig.connectionTimeout);

    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    final dynamic decodedBody = jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (decodedBody is Map<String, dynamic>) {
        return decodedBody;
      }

      throw const FormatException(
        'The server returned an unexpected response.',
      );
    }

    String message = 'The request failed. Please try again.';

    if (decodedBody is Map<String, dynamic> &&
        decodedBody['detail'] is String) {
      message = decodedBody['detail'] as String;
    }

    throw AuthException(message);
  }

  void dispose() {
    _client.close();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}