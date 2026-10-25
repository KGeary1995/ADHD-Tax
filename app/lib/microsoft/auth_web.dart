import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../sync/account_auth.dart';
import 'microsoft_auth.dart';

/// The web app: the same PKCE sign-in as the other platforms (Microsoft
/// treats the page as a single-page app), in a pop-up that comes back to
/// web/auth/microsoft/. Microsoft limits a browser's sign-in to 24 hours,
/// after which sync shows Reconnect (Google's web sign-in lasts one).
AccountAuth createMicrosoftAuth() =>
    MicrosoftAuth(secrets: _LocalStorage(), catcher: _Popup.new);

/// The refresh token in the browser's storage, as the Google web token is:
/// iOS closes home-screen web apps in the background, and reopening one
/// shouldn't mean signing in again.
class _LocalStorage implements SecretStore {
  static String _key(String key) => 'gumption.$key';

  @override
  Future<String?> read(String key) async {
    try {
      return web.window.localStorage.getItem(_key(key));
    } on Object {
      return null; // Storage blocked: sign in again.
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      web.window.localStorage.setItem(_key(key), value);
    } on Object {
      // Private browsing: the sign-in lasts until the tab closes.
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      web.window.localStorage.removeItem(_key(key));
    } on Object {
      // Nothing saved.
    }
  }
}

/// Opens Microsoft's sign-in in a pop-up and waits for
/// web/auth/microsoft/index.html to report where it landed. That page
/// tries three routes, and so does this side: a message to the opener
/// (Microsoft's pages can cut that link), a BroadcastChannel, and local
/// storage, checked every second in case neither event arrives.
class _Popup implements RedirectCatcher {
  static const _type = 'gumption-ms-auth';
  static const _storageKey = 'gumption.ms.auth';

  final _done = Completer<Uri>();
  web.BroadcastChannel? _channel;
  JSFunction? _onMessage;
  Timer? _poll;

  @override
  Future<String> start() async {
    _take(); // A leftover reply from an earlier attempt.
    return Uri.parse(web.document.baseURI)
        .resolve('auth/microsoft/')
        .toString();
  }

  @override
  Future<Uri> open(Uri url) async {
    void accept(Object? data) {
      if (_done.isCompleted) return;
      if (data case {'type': _type, 'url': final String back}) {
        _done.complete(Uri.parse(back));
      }
    }

    _onMessage = ((web.MessageEvent e) {
      if (e.origin == web.window.location.origin) accept(e.data.dartify());
    }).toJS;
    web.window.addEventListener('message', _onMessage);
    try {
      _channel = web.BroadcastChannel(_type)
        ..onmessage = ((web.MessageEvent e) => accept(e.data.dartify())).toJS;
    } on Object {
      // Older browsers: the other two routes still work.
    }
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => accept(_take()));

    final popup = web.window.open(
      url.toString(),
      'gumption-microsoft',
      'popup,width=520,height=680',
    );
    if (popup == null) {
      throw const NeedsReconnect(
        'The browser blocked the Microsoft sign-in window. Allow pop-ups '
        'for this site and try again.',
      );
    }
    return _done.future;
  }

  @override
  Future<void> close() async {
    if (_onMessage != null) {
      web.window.removeEventListener('message', _onMessage);
    }
    _channel?.close();
    _poll?.cancel();
    _take();
  }

  /// Reads and clears the reply the sign-in page left in storage.
  static Object? _take() {
    try {
      final raw = web.window.localStorage.getItem(_storageKey);
      if (raw == null) return null;
      web.window.localStorage.removeItem(_storageKey);
      return jsonDecode(raw);
    } on Object {
      return null;
    }
  }
}
