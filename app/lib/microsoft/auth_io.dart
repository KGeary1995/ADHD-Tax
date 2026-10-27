import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../sync/account_auth.dart';
import 'microsoft_auth.dart';
import 'microsoft_config.dart';

AccountAuth createMicrosoftAuth() => MicrosoftAuth(
  secrets: _Keychain(),
  catcher: Platform.isAndroid
      ? _AndroidLink.new
      // iPhone and iPad: an in-app Safari sheet, as for Google.
      : () => _Loopback(inApp: Platform.isIOS),
);

class _Keychain implements SecretStore {
  // The login keychain on macOS, as for Google (see DesktopGoogleAuth).
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Computers, iPhone and iPad: the browser comes back to a small server on
/// this device (`http://localhost:<port>`), the same way Google sign-in
/// does here. Microsoft accepts any port for a localhost redirect.
class _Loopback implements RedirectCatcher {
  _Loopback({required this.inApp});
  final bool inApp;
  HttpServer? _server;

  @override
  Future<String> start() async {
    final server = _server = await HttpServer.bind('localhost', 0);
    return 'http://localhost:${server.port}';
  }

  @override
  Future<Uri> open(Uri url) async {
    final requests = _server!.asBroadcastStream();
    await launchUrl(
      url,
      mode: inApp
          ? LaunchMode.inAppBrowserView
          : LaunchMode.externalApplication,
    );
    await for (final request in requests) {
      final q = request.uri.queryParameters;
      if (!q.containsKey('code') && !q.containsKey('error')) {
        // A favicon or the like.
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(_doneHtml);
      await request.response.close();
      return request.uri;
    }
    throw const NeedsReconnect('Sign-in didn\'t finish. Try again.');
  }

  @override
  Future<void> close() async {
    await _server?.close(force: true);
    if (inApp) {
      try {
        await closeInAppWebView();
      } on Object {
        // Already closed by the user.
      }
    }
  }
}

/// Android: the sign-in opens in a Custom Tab, and Microsoft sends the
/// browser to `gumption://auth?…`, which brings Gumption back to the front
/// (MainActivity's intent filter) and arrives in [authRedirects].
class _AndroidLink implements RedirectCatcher {
  /// Completes with an error when the sign-in is given up on, so [open]
  /// doesn't wait for a redirect forever.
  final _gaveUp = Completer<Uri>();
  bool _opened = false;

  @override
  Future<String> start() async => MicrosoftConfig.androidRedirect;

  @override
  Future<Uri> open(Uri url) async {
    _opened = true;
    final back = authRedirects.stream.first;
    await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    return Future.any([back, _gaveUp.future]);
  }

  @override
  Future<void> close() async {
    if (_opened && !_gaveUp.isCompleted) {
      _gaveUp.completeError(
        const NeedsReconnect("Sign-in didn't finish. Try again."),
      );
    }
  }
}

const _doneHtml = '''<!doctype html>
<html><head><meta charset="utf-8"><title>Gumption connected</title>
<style>body{font-family:system-ui,sans-serif;background:#0f1115;color:#e6e8ee;
display:grid;place-items:center;height:100vh;margin:0}
div{text-align:center}h1{color:#7c9cff}</style></head>
<body><div><h1>Connected ✓</h1><p>You can close this tab and go back to Gumption.</p></div></body></html>''';
