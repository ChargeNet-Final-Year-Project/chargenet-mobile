import 'dart:convert';

import 'package:chargenet_mobile/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Unit tests for [ApiService]. The JSON client is driven through an
/// injected `http` `MockClient`, so every case is offline and asserts the exact
/// request the service makes.
void main() {
  /// Builds a service whose single client answers with [handler].
  ApiService serviceReturning(http.Response Function(http.Request) handler) {
    return ApiService.withClient(
      MockClient((request) async => handler(request)),
    );
  }

  test('login posts the credentials and decodes the session', () async {
    late http.Request seen;
    final api = serviceReturning((request) {
      seen = request;
      return http.Response(
        jsonEncode({
          'token': 'jwt_123',
          'user': {
            'id': 'usr_1',
            'name': 'Demo Driver',
            'email': 'demo@chargenet.my',
            'createdAt': '2026-03-04T10:00:00Z',
          },
        }),
        200,
      );
    });

    final result = await api.login(
      email: 'demo@chargenet.my',
      password: 'Demo1234!',
    );

    expect(result.token, 'jwt_123');
    expect(result.user.email, 'demo@chargenet.my');
    expect(seen.method, 'POST');
    expect(seen.url.path, endsWith('/api/v1/auth/login'));
    expect(seen.headers['Content-Type'], contains('application/json'));
    expect(jsonDecode(seen.body), {
      'email': 'demo@chargenet.my',
      'password': 'Demo1234!',
    });
  });

  test('an error envelope becomes an ApiException with its codes', () async {
    final api = serviceReturning(
      (request) => http.Response(
        jsonEncode({
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'The email is not valid.',
            'fields': {'email': 'not an email'},
          },
        }),
        400,
      ),
    );

    await expectLater(
      api.login(email: 'x', password: 'y'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.code, 'code', 'VALIDATION_ERROR')
            .having((e) => e.message, 'message', 'The email is not valid.')
            .having((e) => e.fields['email'], 'fields.email', 'not an email'),
      ),
    );
  });

  test('an authenticated call carries the bearer token', () async {
    late http.Request seen;
    final api = serviceReturning((request) {
      seen = request;
      return http.Response(
        jsonEncode({
          'id': 'usr_1',
          'name': 'Demo Driver',
          'email': 'demo@chargenet.my',
          'createdAt': '2026-03-04T10:00:00Z',
        }),
        200,
      );
    });
    api.useToken('jwt_abc');

    final user = await api.me();

    expect(user.id, 'usr_1');
    expect(seen.headers['Authorization'], 'Bearer jwt_abc');
    expect(seen.url.path, endsWith('/api/v1/auth/me'));
  });
}
