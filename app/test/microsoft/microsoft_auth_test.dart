import 'dart:convert';

import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/microsoft/microsoft_auth.dart';
import 'package:adhd_tax/sync/account_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Memory implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// The "browser": records the sign-in page and comes back with [reply].
class _Browser implements RedirectCatcher {
  _Browser(this.reply);
  final Map<String, String> Function(Uri page) reply;
  Uri? page;
  bool closed = false;

  @override
  Future<String> start() async => 'http://localhost:1234';
  @override
  Future<Uri> open(Uri url) async {
    page = url;
    return Uri.parse('http://localhost:1234/')
        .replace(queryParameters: reply(url));
  }

  @override
  Future<void> close() async => closed = true;
}

void main() {
  late _Memory secrets;
  late List<Map<String, String>> tokenCalls;
  late int tokenNo;
  late DateTime now;
  // What the token endpoint says next; null means a normal grant.
  Map<String, Object?>? tokenError;

  setUp(() {
    secrets = _Memory();
    tokenCalls = [];
    tokenNo = 0;
    now = DateTime(2026, 10, 25, 12);
    tokenError = null;
  });

  final api = <String>[];
  http.Client tokenEndpoint() => MockClient((r) async {
    if (r.url.host == 'login.microsoftonline.com') {
      tokenCalls.add(r.bodyFields);
      if (tokenError != null) {
        return http.Response(jsonEncode(tokenError), 400);
      }
      tokenNo++;
      return http.Response(
        jsonEncode({
          'access_token': 'access-$tokenNo',
          'refresh_token': 'refresh-$tokenNo',
          'expires_in': 3600,
        }),
        200,
      );
    }
    api.add(r.headers['Authorization'] ?? '');
    return http.Response('{}', 200);
  });

  MicrosoftAuth auth(_Browser browser, {http.Client? client}) {
    final c = client ?? tokenEndpoint();
    return MicrosoftAuth(
      secrets: secrets,
      catcher: () => browser,
      clientId: 'client-1',
      newClient: () => c,
      now: () => now,
    );
  }

  _Browser echo() => _Browser(
    (page) => {'code': 'the-code', 'state': page.queryParameters['state']!},
  );

  test('no client id: not offered', () {
    expect(
      MicrosoftAuth(secrets: secrets, catcher: echo, clientId: '').isConfigured,
      isFalse,
    );
  });

  test('connect: PKCE sign-in for any Microsoft account, then the code is '
      'traded for tokens and the refresh token kept', () async {
    final browser = echo();
    final a = auth(browser);
    final client = await a.connect(Workspace.work, email: 'k@contoso.com');

    final q = browser.page!.queryParameters;
    expect(browser.page!.path, '/common/oauth2/v2.0/authorize');
    expect(q['client_id'], 'client-1');
    expect(q['redirect_uri'], 'http://localhost:1234');
    expect(q['scope'], contains('Files.ReadWrite.AppFolder'));
    expect(q['scope'], contains('offline_access'));
    expect(q['prompt'], 'select_account');
    expect(q['login_hint'], 'k@contoso.com');
    expect(q['code_challenge_method'], 'S256');

    final exchange = tokenCalls.single;
    expect(exchange['grant_type'], 'authorization_code');
    expect(exchange['code'], 'the-code');
    expect(exchange['redirect_uri'], 'http://localhost:1234');
    final verifier = exchange['code_verifier']!;
    expect(
      q['code_challenge'],
      base64Url
          .encode(sha256.convert(ascii.encode(verifier)).bytes)
          .replaceAll('=', ''),
    );
    expect(browser.closed, isTrue);
    expect(secrets.values['microsoft.credentials.work'], contains('refresh-1'));

    await client.get(Uri.parse('https://graph.microsoft.com/v1.0/me'));
    expect(api.last, 'Bearer access-1');
  });

  test('a reply for another sign-in (wrong state) is refused', () async {
    final a = auth(_Browser((_) => {'code': 'x', 'state': 'forged'}));
    await expectLater(
      a.connect(Workspace.personal),
      throwsA(isA<NeedsReconnect>()),
    );
    expect(tokenCalls, isEmpty);
    expect(secrets.values, isEmpty);
  });

  test('cancelling on the Microsoft page says so', () async {
    final a = auth(
      _Browser(
        (page) => {
          'error': 'access_denied',
          'state': page.queryParameters['state']!,
        },
      ),
    );
    await expectLater(
      a.connect(Workspace.personal),
      throwsA(
        isA<NeedsReconnect>().having(
          (e) => e.reason,
          'reason',
          contains('cancelled'),
        ),
      ),
    );
  });

  test('restore renews once for requests that arrive together, keeps the '
      'new refresh token, and renews again when the hour is up', () async {
    secrets.values['microsoft.credentials.personal'] = jsonEncode({
      'refresh_token': 'old',
    });
    final client = (await auth(echo()).restore(Workspace.personal))!;
    final url = Uri.parse('https://graph.microsoft.com/v1.0/me');
    await Future.wait([client.get(url), client.get(url), client.get(url)]);
    expect(tokenCalls, hasLength(1));
    expect(tokenCalls.single['refresh_token'], 'old');
    expect(api.sublist(api.length - 3), everyElement('Bearer access-1'));
    expect(
      secrets.values['microsoft.credentials.personal'],
      contains('refresh-1'),
    );

    now = now.add(const Duration(minutes: 59, seconds: 30));
    await client.get(url);
    expect(tokenCalls, hasLength(2));
    expect(tokenCalls.last['refresh_token'], 'refresh-1');
    expect(api.last, 'Bearer access-2');
  });

  test('an expired or removed grant asks to sign in again', () async {
    secrets.values['microsoft.credentials.personal'] = jsonEncode({
      'refresh_token': 'old',
    });
    tokenError = {'error': 'invalid_grant'};
    final client = (await auth(echo()).restore(Workspace.personal))!;
    await expectLater(
      client.get(Uri.parse('https://graph.microsoft.com/v1.0/me')),
      throwsA(isA<NeedsReconnect>()),
    );
  });

  test('nothing saved: restore needs the user; disconnect forgets', () async {
    final a = auth(echo());
    expect(await a.restore(Workspace.work), isNull);
    await a.connect(Workspace.work);
    expect(await a.restore(Workspace.work), isNotNull);
    await a.disconnect(Workspace.work);
    expect(await a.restore(Workspace.work), isNull);
  });

  test('each workspace keeps its own sign-in', () async {
    final a = auth(echo());
    await a.connect(Workspace.personal);
    expect(await a.restore(Workspace.work), isNull);
    expect(secrets.values.keys, ['microsoft.credentials.personal']);
  });

  test(
    'Android: the browser comes back through the gumption://auth link',
    () async {
      final back = authRedirects.stream.first;
      authRedirects.add(Uri.parse('gumption://auth?code=c&state=s'));
      expect((await back).queryParameters['code'], 'c');
    },
  );
}
