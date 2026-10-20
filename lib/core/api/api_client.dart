import 'dart:async';

import 'package:dio/dio.dart';
import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/core/storage/token_store.dart';

class ApiClient {
  ApiClient({required String baseUrl, required TokenStore tokenStore, Dio? dio})
    : _tokenStore = tokenStore,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl.replaceAll(RegExp(r'/$'), ''),
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 18),
              sendTimeout: const Duration(seconds: 18),
              contentType: Headers.jsonContentType,
              validateStatus: (_) => true,
            ),
          );

  final Dio _dio;
  final TokenStore _tokenStore;
  TokenPair? _tokens;
  Future<bool>? _refreshInFlight;

  Future<bool> restoreSession() async {
    _tokens = await _tokenStore.read();
    return _tokens != null;
  }

  Future<void> saveTokens(TokenPair tokens) async {
    _tokens = tokens;
    await _tokenStore.write(tokens);
  }

  /// For the settings page: the next request goes out with a dead access
  /// token, so the 401 → refresh → retry path runs. The stored pair is kept.
  void debugExpireAccessToken() {
    final tokens = _tokens;
    if (tokens == null) return;
    _tokens = TokenPair(
      accessToken: 'expired-by-settings',
      refreshToken: tokens.refreshToken,
    );
  }

  Future<void> clearSession() async {
    _tokens = null;
    await _tokenStore.clear();
  }

  Future<T> publicRequest<T>(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? query,
    required T Function(dynamic data) decode,
  }) async {
    final response = await _send(
      path,
      method: method,
      data: data,
      query: query,
    );
    return decode(_unwrap(response));
  }

  Future<T> request<T>(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? query,
    required T Function(dynamic data) decode,
  }) async {
    _tokens ??= await _tokenStore.read();
    final attemptedAccessToken = _tokens?.accessToken;
    var response = await _send(
      path,
      method: method,
      data: data,
      query: query,
      accessToken: attemptedAccessToken,
    );

    final anotherRequestAlreadyRenewed =
        attemptedAccessToken != null &&
        _tokens?.accessToken != null &&
        _tokens?.accessToken != attemptedAccessToken;
    if (response.statusCode == 401 &&
        (anotherRequestAlreadyRenewed || await _refreshOnce())) {
      response = await _send(
        path,
        method: method,
        data: data,
        query: query,
        accessToken: _tokens?.accessToken,
      );
    }
    return decode(_unwrap(response));
  }

  Future<Response<dynamic>> _send(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? query,
    String? accessToken,
  }) async {
    try {
      return await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );
    } on DioException catch (error) {
      final timeout = {
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      }.contains(error.type);
      throw ApiException(
        timeout
            ? 'Сервер не ответил вовремя. Попробуй ещё раз.'
            : 'Нет соединения с сервером.',
        isNetwork: true,
      );
    }
  }

  dynamic _unwrap(Response<dynamic> response) {
    final body = response.data;
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (error is Map) {
        throw ApiException(
          error['message']?.toString() ?? 'Что-то пошло не так',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode != null && response.statusCode! >= 400) {
        throw ApiException(
          'Сервер вернул ошибку ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      return body['data'];
    }
    throw ApiException(
      'Не удалось прочитать ответ сервера',
      statusCode: response.statusCode,
    );
  }

  Future<bool> _refreshOnce() {
    final active = _refreshInFlight;
    if (active != null) return active;
    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _performRefresh() async {
    final refreshToken = _tokens?.refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await _send(
        '/auth/renew-token',
        method: 'POST',
        data: {'refreshToken': refreshToken},
      );
      final raw = _unwrap(response) as Map<String, dynamic>;
      await saveTokens(TokenPair.fromJson(raw));
      return true;
    } catch (_) {
      await clearSession();
      return false;
    }
  }
}
