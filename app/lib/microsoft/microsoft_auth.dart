/// Microsoft sign-in for OneDrive sync: OAuth with PKCE against the
/// `common` endpoint (personal and work or school accounts), one refresh
/// token per workspace. Pure Dart: the browser step ([RedirectCatcher]) and
/// the keychain ([SecretStore]) are handed in, so tests run without either.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../data/models/task.dart';
import '../sync/account_auth.dart';
import 'microsoft_config.dart';

/// Opens the sign-in page and waits for the browser to come back.
abstract class RedirectCatcher {
  /// Sets up where the browser returns to; the same address goes in the
  /// authorize and token requests. Call [close] when done.
  Future<String> start();

  /// Opens [url] and completes with the address the browser came back to.
  Future<Uri> open(Uri url);

  Future<void> close();
}

/// The OS keychain, or memory in tests.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class MicrosoftAuth implements AccountAuth {
  MicrosoftAuth({
    required this.secrets,
    required this.catcher,
    this.clientId = MicrosoftConfig.clientId,
    http.Client Function() newClient = http.Client.new,
    DateTime Function()? now,
  }) : _newClient = newClient,
       _http = newClient(),
       _now = now ?? DateTime.now;

  final SecretStore secrets;
  final RedirectCatcher Function() catcher;
  final String clientId;

  /// Each connected workspace gets its own client (the sync controller
  /// closes it when done); token requests share [_http].
  final http.Client Function() _newClient;
  final http.Client _http;
  final DateTime Function() _now;

  /// Per workspace, bumped by [disconnect] and each new sign-in. A client
  /// made under an older number may still finish a token renewal, but
  /// doesn't save its refresh token: that would bring back credentials
  /// just deleted, or replace a newer sign-in's.
  final _generation = <Workspace, int>{};

  @override
  bool get isConfigured => clientId.isNotEmpty;

  @override
  bool get restoreMayRecover => false;

  String _key(Workspace ws) => 'microsoft.credentials.${ws.name}';

  @override
  Future<http.Client?> restore(Workspace ws, {String? email}) async {
    final raw = await secrets.read(_key(ws));
    if (raw == null) return null;
    final refresh = (jsonDecode(raw) as Map)['refresh_token'];
    if (refresh is! String) return null;
    return _client(ws, _Tokens(refresh));
  }

  @override
  Future<http.Client> connect(Workspace ws, {String? email}) async {
    final browser = catcher();
    try {
      final redirect = await browser.start();
      final verifier = _random(64);
      final state = _random(24);
      final url = Uri.parse('${MicrosoftConfig.authority}/authorize').replace(
        queryParameters: {
          'client_id': clientId,
          'response_type': 'code',
          'redirect_uri': redirect,
          'response_mode': 'query',
          'scope': MicrosoftConfig.scopes,
          'state': state,
          'code_challenge': _challenge(verifier),
          'code_challenge_method': 'S256',
          // Pick Personal vs Work deliberately, not whoever's signed in.
          'prompt': 'select_account',
          'login_hint': ?email,
        },
      );
      final back = await browser.open(url);
      final q = back.queryParameters;
      if (q['state'] != state) {
        throw const NeedsReconnect('Sign-in didn\'t finish. Try again.');
      }
      if (q['error'] != null) {
        throw NeedsReconnect(
          q['error'] == 'access_denied'
              ? 'Sign-in was cancelled.'
              : 'Microsoft sign-in failed: '
                    '${q['error_description'] ?? q['error']}',
        );
      }
      final body = await _token({
        'grant_type': 'authorization_code',
        'code': q['code'] ?? '',
        'redirect_uri': redirect,
        'code_verifier': verifier,
      });
      final refresh = body['refresh_token'];
      // Without one, sync would stop within the hour (offline_access
      // missing from the app registration's permissions).
      if (refresh is! String) {
        throw const NeedsReconnect(
          'Microsoft didn\'t allow staying signed in. Check the app '
          'registration\'s offline_access permission.',
        );
      }
      final tokens = _Tokens(refresh)..take(body, _now());
      _generation[ws] = (_generation[ws] ?? 0) + 1;
      await _save(ws, tokens.refresh);
      return _client(ws, tokens);
    } finally {
      await browser.close();
    }
  }

  @override
  Future<void> disconnect(Workspace ws, {String? email}) {
    _generation[ws] = (_generation[ws] ?? 0) + 1;
    // Microsoft has no revoke endpoint for an app like this; the grant
    // stays listed at account.microsoft.com → Privacy → Apps, where the
    // user can remove it.
    return secrets.delete(_key(ws));
  }

  Future<void> _save(Workspace ws, String refresh) =>
      secrets.write(_key(ws), jsonEncode({'refresh_token': refresh}));

  http.Client _client(Workspace ws, _Tokens tokens) {
    final generation = _generation[ws] ?? 0;
    Future<String>? renewing;
    Future<String> renew() async {
      final body = await _token({
        'grant_type': 'refresh_token',
        'refresh_token': tokens.refresh,
      });
      final before = tokens.refresh;
      tokens.take(body, _now());
      // Microsoft hands out a new refresh token with each renewal.
      if (tokens.refresh != before && generation == (_generation[ws] ?? 0)) {
        await _save(ws, tokens.refresh);
      }
      return tokens.access!;
    }

    return BearerClient(
      () {
        if (tokens.validAt(_now())) return Future.value(tokens.access!);
        // Requests that arrive together share one renewal.
        return renewing ??= renew().whenComplete(() => renewing = null);
      },
      inner: _newClient(),
      onUnauthorized: (_) async => tokens.access = null,
    );
  }

  Future<Map<String, Object?>> _token(Map<String, String> fields) async {
    final res = await _http.post(
      Uri.parse('${MicrosoftConfig.authority}/token'),
      body: {'client_id': clientId, 'scope': MicrosoftConfig.scopes, ...fields},
    );
    final body = res.body.isEmpty
        ? const <String, Object?>{}
        : jsonDecode(res.body) as Map<String, Object?>;
    if (res.statusCode == 200 && body['access_token'] is String) return body;
    // invalid_grant: the refresh token expired or the app was removed from
    // the account. Anything else from the token endpoint also needs the
    // user, so never retry quietly.
    throw NeedsReconnect(
      body['error'] == 'invalid_grant'
          ? 'Microsoft needs you to sign in again.'
          : 'Microsoft sign-in failed: '
                '${body['error_description'] ?? body['error'] ?? res.statusCode}',
    );
  }
}

class _Tokens {
  _Tokens(this.refresh);
  String refresh;
  String? access;
  DateTime? expires;

  void take(Map<String, Object?> body, DateTime now) {
    access = body['access_token'] as String;
    refresh = body['refresh_token'] as String? ?? refresh;
    final life = body['expires_in'];
    // A minute early, so a request never goes out with a dying token.
    expires = now.add(
      Duration(seconds: (life is int ? life : int.tryParse('$life') ?? 0) - 60),
    );
  }

  bool validAt(DateTime now) =>
      access != null && expires != null && now.isBefore(expires!);
}

final _rng = Random.secure();
const _chars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

String _random(int length) =>
    List.generate(length, (_) => _chars[_rng.nextInt(_chars.length)]).join();

/// PKCE S256: base64url(sha256(verifier)) without padding.
String _challenge(String verifier) => base64Url
    .encode(sha256.convert(ascii.encode(verifier)).bytes)
    .replaceAll('=', '');

/// Android: the browser comes back through a `gumption://auth?…` link,
/// which MainActivity passes over the device channel and OutsideBootstrap
/// drops here.
final authRedirects = StreamController<Uri>.broadcast();
