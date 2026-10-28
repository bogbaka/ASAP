
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_storage.dart';

class AuthService {
  AuthService({
    http.Client? client,
    TokenStorage? tokenStorage,
  })  : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final http.Client _client;
  final TokenStorage _tokenStorage;

  Uri _endpoint(String path) {
    return Uri.parse('${ApiConfig.baseUrl}$path');
  }

  /// Requests a verification code for a phone number.
  Future<Map<String, dynamic>> requestOtp({
    required String phoneNumber,
  }) {
    return _post(
      '/auth/request-otp',
      {'phone_number': phoneNumber},
    );
  }

  /// Requests another verification code.
  Future<Map<String, dynamic>> resendOtp({
    required String phoneNumber,
  }) {
    return _post(
      '/auth/resend-otp',
      {'phone_number': phoneNumber},
    );
  }

  /// Verifies the code and returns the backend response.
  Future<Map<String, dynamic>> verifyOtp({
    required String phoneNumber,
    required String code,
  }) {
    return _post(
      '/auth/verify-otp',
      {
        'phone_number': phoneNumber,
        'code': code,
      },
    );
  }

  /// Registers a new user after successful OTP verification.
  Future<Map<String, dynamic>> register({
    required String registrationToken,
    required String displayName,
    String? email,
  }) {
    return _post(
      '/auth/register',
      {
        'registration_token': registrationToken,
        'display_name': displayName,
        if (email != null && email.trim().isNotEmpty)
          'email': email.trim(),
      },
    );
  }

  /// Retrieves the currently authenticated user's profile.
  Future<Map<String, dynamic>> getMyProfile({
    required String accessToken,
  }) async {
    try {
      final response = await _client
          .get(
            _endpoint('/auth/me'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(ApiConfig.connectionTimeout);

      return _decodeResponse(response);
    } on AuthException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Could not connect to the server. Check your connection and try again.',
      );
    }
  }

  /// Updates the currently authenticated user's profile.
  Future<Map<String, dynamic>> updateMyProfile({
    required String accessToken,
    required String displayName,
    required String email,
    required String about,
  }) async {
    try {
      final response = await _client
          .patch(
            _endpoint('/auth/me'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'display_name': displayName.trim(),
              'email': email.trim().isEmpty
                  ? null
                  : email.trim(),
              'about': about.trim().isEmpty
                  ? null
                  : about.trim(),
            }),
          )
          .timeout(ApiConfig.connectionTimeout);

      return _decodeResponse(response);
    } on AuthException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Could not connect to the server. Check your connection and try again.',
      );
    }
  }

  /// Saves the access token securely on the device.
  Future<void> saveAccessToken(String token) async {
    try {
      await _tokenStorage.saveAccessToken(token);
    } catch (_) {
      throw const AuthException(
        'Could not securely save your session. Please try again.',
      );
    }
  }

  /// Retrieves the saved access token.
  Future<String?> getAccessToken() async {
    try {
      return await _tokenStorage.getAccessToken();
    } catch (_) {
      throw const AuthException(
        'Could not retrieve your saved session.',
      );
    }
  }

  /// Clears the saved access token, for example when logging out.
  Future<void> clearAccessToken() async {
    try {
      await _tokenStorage.deleteAccessToken();
    } catch (_) {
      throw const AuthException(
        'Could not clear your saved session.',
      );
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(
            _endpoint(path),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.connectionTimeout);

      return _decodeResponse(response);
    } on AuthException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Could not connect to the server. Check your connection and try again.',
      );
    }
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    dynamic decodedBody;

    try {
      decodedBody = jsonDecode(response.body);
    } on FormatException {
      throw const FormatException(
        'The server returned an invalid response.',
      );
    }

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

    if (decodedBody is Map<String, dynamic>) {
      final detail = decodedBody['detail'];

      if (detail is String) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        final firstError = detail.first;

        if (firstError is Map<String, dynamic> &&
            firstError['msg'] is String) {
          message = firstError['msg'] as String;
        }
      }
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
