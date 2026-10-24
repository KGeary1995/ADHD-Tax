import 'dart:async';
import 'dart:convert';

import 'package:google_identity_services_web/loader.dart' as gis;
import 'package:google_identity_services_web/oauth2.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import '../data/models/task.dart';
import 'google_auth.dart';
import 'google_config.dart';

GoogleAuth createGoogleAuth() => WebGoogleAuth();

/// Web: Google Identity Services token flow, one token per workspace with a
/// login hint so Personal and Work stay on their own accounts.
///
/// Browsers only get short-lived tokens (about an hour) and can't refresh
/// them without a click, so after that sync shows "Reconnect". The token is
/// kept in local storage until it expires: iOS closes home-screen web apps
/// in the background, and reopening one shouldn't mean signing in again.
class WebGoogleAuth implements GoogleAuth {
  WebGoogleAuth() {
    for (final ws in Workspace.values) {
      final saved = _load(ws);
      if (saved != null) _tokens[ws] = saved;
    }
  }

  final Map<Workspace, (String token, DateTime expires)> _tokens = {};
  Future<void>? _loaded;

  // Pre-rename prefix kept so saved sign-ins survive the update.
  static String _key(Workspace ws) => 'adhdtax.googleToken.${ws.name}';

  static (String, DateTime)? _load(Workspace ws) {
    try {
      final raw = web.window.localStorage.getItem(_key(ws));
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, Object?>;
      final expires = DateTime.fromMillisecondsSinceEpoch(j['expires'] as int);
      if (DateTime.now().isAfter(expires)) return null;
      return (j['token'] as String, expires);
    } on Object {
      return null; // Storage blocked or unreadable: just sign in again.
    }
  }

  void _save(Workspace ws) {
    try {
      final t = _tokens[ws];
      if (t == null) {
        web.window.localStorage.removeItem(_key(ws));
      } else {
        web.window.localStorage.setItem(
          _key(ws),
          jsonEncode({'token': t.$1, 'expires': t.$2.millisecondsSinceEpoch}),
        );
      }
    } on Object {
      // Private browsing: the token just lives in memory.
    }
  }

  @override
  bool get isConfigured => GoogleConfig.webClientId.isNotEmpty;

  @override
  bool get restoreMayRecover => false;

  String _currentToken(Workspace ws) {
    final t = _tokens[ws];
    if (t == null || DateTime.now().isAfter(t.$2)) {
      throw const NeedsReconnect('Browser session ended');
    }
    return t.$1;
  }

  http.Client _client(Workspace ws) => BearerClient(
    () async => _currentToken(ws),
    onUnauthorized: (_) async {
      _tokens.remove(ws);
      _save(ws);
    },
  );

  @override
  Future<http.Client?> restore(Workspace ws, {String? email}) async {
    final t = _tokens[ws];
    return t != null && DateTime.now().isBefore(t.$2) ? _client(ws) : null;
  }

  @override
  Future<http.Client> connect(Workspace ws, {String? email}) async {
    await (_loaded ??= gis.loadWebSdk());
    final done = Completer<void>();
    final client = oauth2.initTokenClient(
      TokenClientConfig(
        client_id: GoogleConfig.webClientId,
        scope: GoogleConfig.scopes,
        login_hint: email,
        prompt: email == null ? 'select_account' : '',
        callback: (TokenResponse r) {
          final token = r.access_token;
          if (r.error != null || token == null) {
            done.completeError(
              NeedsReconnect(
                r.error_description ?? r.error ?? 'Sign-in failed',
              ),
            );
            return;
          }
          // Refresh a minute early so a request never races the expiry.
          final seconds = (r.expires_in ?? 3600) - 60;
          _tokens[ws] = (token, DateTime.now().add(Duration(seconds: seconds)));
          _save(ws);
          done.complete();
        },
        error_callback: (GoogleIdentityServicesError? e) {
          if (!done.isCompleted) {
            done.completeError(NeedsReconnect(e?.message ?? 'Sign-in closed'));
          }
        },
      ),
    );
    client.requestAccessToken();
    await done.future;
    return _client(ws);
  }

  @override
  Future<void> disconnect(Workspace ws, {String? email}) async {
    final t = _tokens.remove(ws);
    if (t != null) oauth2.revoke(t.$1);
  }
}
