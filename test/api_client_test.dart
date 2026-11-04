import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/api/api_client.dart';
import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiClient', () {
    test('unwraps a successful response envelope', () async {
      final harness = _Harness(
        (options) => _json(200, {
          'data': {'value': 7},
          'error': null,
        }),
      );

      final value = await harness.client.publicRequest<int>(
        '/value',
        decode: (data) => (data as Map)['value'] as int,
      );

      expect(value, 7);
    });

    test('throws the server error from an error envelope', () async {
      final harness = _Harness(
        (options) => _json(400, {
          'data': null,
          'error': {'message': 'bad input', 'code': 400},
        }),
      );

      expect(
        () => harness.client.publicRequest<void>('/value', decode: (_) {}),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'bad input',
          ),
        ),
      );
    });

    test('maps a transport timeout to a user-facing network error', () async {
      final harness = _Harness(
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(
        harness.client.publicRequest<void>('/slow', decode: (_) {}),
        throwsA(
          isA<ApiException>()
              .having((error) => error.isNetwork, 'isNetwork', isTrue)
              .having((error) => error.message, 'message', contains('вовремя')),
        ),
      );
    });

    test('adds the access token to protected requests', () async {
      String? authorization;
      final harness = _Harness(
        (options) {
          authorization = options.headers['Authorization'] as String?;
          return _json(200, {
            'data': {'ok': true},
            'error': null,
          });
        },
        tokens: const TokenPair(accessToken: 'access', refreshToken: 'refresh'),
      );

      await harness.client.request<void>('/protected', decode: (_) {});

      expect(authorization, 'Bearer access');
    });

    test('successful sign-in persists both tokens', () async {
      final harness = _Harness(
        (options) => _json(200, {
          'data': {
            'accessToken': 'signed-access',
            'refreshToken': 'signed-refresh',
          },
          'error': null,
        }),
      );
      final repository = DrunaRepository(harness.client);

      await repository.signIn('alice', 'secret123');

      expect((await harness.store.read())?.accessToken, 'signed-access');
      expect((await harness.store.read())?.refreshToken, 'signed-refresh');
    });

    test(
      'parallel 401 responses cause one refresh and both requests retry once',
      () async {
        var renewCount = 0;
        var protectedCount = 0;
        final initialResponses = Completer<void>();
        final harness = _Harness(
          (options) async {
            if (options.path.endsWith('/auth/renew-token')) {
              renewCount++;
              return _json(200, {
                'data': {
                  'accessToken': 'new-access',
                  'refreshToken': 'new-refresh',
                },
                'error': null,
              });
            }
            protectedCount++;
            if (options.headers['Authorization'] != 'Bearer new-access') {
              if (protectedCount == 2) initialResponses.complete();
              await initialResponses.future;
              return _json(401, {
                'data': null,
                'error': {'message': 'expired', 'code': 401},
              });
            }
            return _json(200, {
              'data': {'ok': true},
              'error': null,
            });
          },
          tokens: const TokenPair(
            accessToken: 'old-access',
            refreshToken: 'old-refresh',
          ),
        );

        final results = await Future.wait([
          harness.client.request<bool>(
            '/one',
            decode: (data) => (data as Map)['ok'] as bool,
          ),
          harness.client.request<bool>(
            '/two',
            decode: (data) => (data as Map)['ok'] as bool,
          ),
        ]);

        expect(results, [true, true]);
        expect(renewCount, 1);
        expect(protectedCount, 4);
        expect((await harness.store.read())?.refreshToken, 'new-refresh');
      },
    );

    test('a refused refresh clears the session and says it expired', () async {
      final harness = _Harness(
        (options) => options.path.endsWith('/auth/renew-token')
            ? _json(401, {
                'data': null,
                'error': {'message': 'invalid refresh', 'code': 401},
              })
            : _json(401, {
                'data': null,
                'error': {'message': 'expired', 'code': 401},
              }),
        tokens: const TokenPair(accessToken: 'old', refreshToken: 'bad'),
      );
      var expired = 0;
      harness.client.onSessionExpired = () => expired++;

      await expectLater(
        harness.client.request<void>('/protected', decode: (_) {}),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            401,
          ),
        ),
      );
      expect(await harness.store.read(), isNull);
      expect(expired, 1);
    });

    test('a lost connection while renewing keeps the session', () async {
      var expired = 0;
      final harness = _Harness(
        (options) => options.path.endsWith('/auth/renew-token')
            ? throw DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              )
            : _json(401, {
                'data': null,
                'error': {'message': 'expired', 'code': 401},
              }),
        tokens: const TokenPair(accessToken: 'old', refreshToken: 'good'),
      );
      harness.client.onSessionExpired = () => expired++;

      await expectLater(
        harness.client.request<void>('/protected', decode: (_) {}),
        throwsA(
          isA<ApiException>().having((e) => e.isNetwork, 'network', isTrue),
        ),
      );
      expect((await harness.store.read())?.refreshToken, 'good');
      expect(expired, 0);
    });

    test('a refused refresh sends the user back to sign in', () async {
      final harness = _Harness(
        (options) => _json(401, {
          'data': null,
          'error': {'message': 'expired', 'code': 401},
        }),
        tokens: const TokenPair(accessToken: 'old', refreshToken: 'bad'),
      );
      final session = SessionController(DrunaRepository(harness.client));
      await session.restore();

      expect(session.state, SessionState.signedOut);
      expect(session.takeExpiredSignOut(), isTrue);
      expect(session.takeExpiredSignOut(), isFalse);
      expect(await harness.store.read(), isNull);
    });
  });
}

class _Harness {
  _Harness(_Handler handler, {TokenPair? tokens})
    : store = MemoryTokenStore(tokens) {
    client = ApiClient(
      baseUrl: 'https://example.test',
      tokenStore: store,
      dio: _dio(handler),
    );
  }

  final MemoryTokenStore store;
  late final ApiClient client;
}

typedef _Handler = FutureOr<ResponseBody> Function(RequestOptions options);

Dio _dio(_Handler handler) {
  final dio = Dio(
    BaseOptions(baseUrl: 'https://example.test', validateStatus: (_) => true),
  );
  dio.httpClientAdapter = _Adapter(handler);
  return dio;
}

ResponseBody _json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final _Handler handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}
