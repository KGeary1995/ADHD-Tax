import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../data/models/task.dart';
import 'google_auth.dart';
import 'google_config.dart';

GoogleAuth createGoogleAuth() => Platform.isAndroid
    ? MobileGoogleAuth()
    // iPhone uses the same browser sign-in as computers, in an in-app
    // Safari sheet: Google Sign-In on iOS keeps one account at a time and
    // ignores which email is asked for, so Personal and Work could end up
    // syncing through the same account.
    : DesktopGoogleAuth(inApp: Platform.isIOS);

/// Android: Google Sign-In. Tokens are requested per account email, so
/// Personal and Work can be different Google accounts at once.
class MobileGoogleAuth implements GoogleAuth {
  Future<void>? _init;

  @override
  bool get restoreMayRecover => true;

  @override
  bool get isConfigured =>
      GoogleConfig.webClientId.isNotEmpty &&
      (!Platform.isIOS || GoogleConfig.iosClientId.isNotEmpty);

  Future<void> _ensureInit() => _init ??= GoogleSignIn.instance.initialize(
    clientId: Platform.isIOS ? GoogleConfig.iosClientId : null,
    serverClientId: GoogleConfig.webClientId,
  );

  Future<String?> _token(String email, {required bool prompt}) async {
    await _ensureInit();
    final tokens = await GoogleSignInPlatform.instance
        .clientAuthorizationTokensForScopes(
          ClientAuthorizationTokensForScopesParameters(
            request: AuthorizationRequestDetails(
              scopes: GoogleConfig.scopes,
              userId: null,
              email: email,
              promptIfUnauthorized: prompt,
            ),
          ),
        );
    return tokens?.accessToken;
  }

  http.Client _client(String email) => BearerClient(
    () async =>
        await _token(email, prompt: false) ??
        (throw const NeedsReconnect('Google needs you to sign in again')),
    onUnauthorized: (token) =>
        GoogleSignInPlatform.instance.clearAuthorizationToken(
          ClearAuthorizationTokenParams(accessToken: token),
        ),
  );

  @override
  Future<http.Client?> restore(Workspace ws, {String? email}) async {
    if (email == null) return null;
    return await _token(email, prompt: false) == null ? null : _client(email);
  }

  @override
  Future<http.Client> connect(Workspace ws, {String? email}) async {
    await _ensureInit();
    // Always show the account picker so Work can use a different account
    // than Personal.
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: GoogleConfig.scopes,
    );
    await _token(account.email, prompt: true);
    return _client(account.email);
  }

  @override
  Future<void> disconnect(Workspace ws, {String? email}) async {
    // Google Sign-In on Android can only sign out every account at once,
    // which would break the other workspace. Forgetting the email (done by
    // the caller) is enough to stop syncing this one.
  }
}

/// Windows, macOS, Linux: OAuth in the system browser with a loopback
/// redirect (PKCE). The refresh token goes to the OS keychain, one per
/// workspace.
///
/// Also iPhone and iPad ([inApp]): the sign-in page opens in an in-app
/// Safari sheet, which closes itself once Google redirects back. Each
/// workspace keeps its own refresh token, so two accounts work side by side.
class DesktopGoogleAuth implements GoogleAuth {
  DesktopGoogleAuth({FlutterSecureStorage? storage, this.inApp = false})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // The login keychain works in an unsigned/ad-hoc signed build;
            // the data-protection keychain needs a team-signed entitlement.
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final FlutterSecureStorage _storage;
  final bool inApp;

  static final _clientId = ClientId(
    GoogleConfig.desktopClientId,
    GoogleConfig.desktopClientSecret,
  );

  @override
  bool get restoreMayRecover => false;

  @override
  bool get isConfigured =>
      GoogleConfig.desktopClientId.isNotEmpty &&
      GoogleConfig.desktopClientSecret.isNotEmpty;

  String _key(Workspace ws) => 'google.credentials.${ws.name}';

  Future<void> _save(Workspace ws, AccessCredentials c) =>
      _storage.write(key: _key(ws), value: jsonEncode(c.toJson()));

  http.Client _client(Workspace ws, AccessCredentials creds) {
    final client = autoRefreshingClient(_clientId, creds, http.Client());
    // The access token renews about hourly; only the refresh token needs
    // keeping. Writing the keychain on every renewal made macOS ask for the
    // keychain password again and again (ad-hoc signed builds aren't
    // trusted by the item's access list).
    var kept = creds.refreshToken;
    client.credentialUpdates.listen((c) {
      if (c.refreshToken == null || c.refreshToken == kept) return;
      kept = c.refreshToken;
      _save(ws, c);
    });
    return client;
  }

  @override
  Future<http.Client?> restore(Workspace ws, {String? email}) async {
    final raw = await _storage.read(key: _key(ws));
    if (raw == null) return null;
    final creds = AccessCredentials.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    if (creds.refreshToken == null) return null;
    return _client(ws, creds);
  }

  @override
  Future<http.Client> connect(Workspace ws, {String? email}) async {
    final base = http.Client();
    try {
      final creds = await obtainAccessCredentialsViaUserConsent(
        _clientId,
        GoogleConfig.scopes,
        base,
        (url) {
          // select_account: pick Work vs Personal deliberately.
          // consent: guarantees a refresh token on reconnect.
          final hint = email == null
              ? ''
              : '&login_hint=${Uri.encodeQueryComponent(email)}';
          launchUrl(
            Uri.parse('$url&prompt=select_account%20consent$hint'),
            mode: inApp
                ? LaunchMode.inAppBrowserView
                : LaunchMode.externalApplication,
          );
        },
        customPostAuthPage: _doneHtml,
      );
      await _save(ws, creds);
      return _client(ws, creds);
    } finally {
      base.close();
      if (inApp) {
        try {
          await closeInAppWebView();
        } on Object {
          // Already closed by the user.
        }
      }
    }
  }

  @override
  Future<void> disconnect(Workspace ws, {String? email}) async {
    final raw = await _storage.read(key: _key(ws));
    await _storage.delete(key: _key(ws));
    if (raw == null) return;
    final token = AccessCredentials.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    ).refreshToken;
    if (token == null) return;
    // Best effort: revoke so the grant disappears from the Google account.
    try {
      await http.post(
        Uri.parse('https://oauth2.googleapis.com/revoke'),
        body: {'token': token},
      );
    } on Object {
      // Offline: the local credentials are gone either way.
    }
  }
}

const _doneHtml = '''<!doctype html>
<html><head><meta charset="utf-8"><title>Gumption connected</title>
<style>body{font-family:system-ui,sans-serif;background:#0f1115;color:#e6e8ee;
display:grid;place-items:center;height:100vh;margin:0}
div{text-align:center}h1{color:#7c9cff}</style></head>
<body><div><h1>Connected ✓</h1><p>You can close this tab and go back to Gumption.</p></div></body></html>''';
