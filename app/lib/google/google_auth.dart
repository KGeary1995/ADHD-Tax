import 'package:http/http.dart' as http;

import '../data/models/task.dart';

/// Thrown when a stored sign-in can't be used without the user (expired,
/// revoked, or a web session that ended). The UI offers "Reconnect".
class NeedsReconnect implements Exception {
  const NeedsReconnect([this.reason = 'Sign-in expired']);
  final String reason;

  @override
  String toString() => reason;
}

/// Signs a workspace into a Google account and hands back an HTTP client
/// that authenticates Drive calls. Each workspace has its own account.
abstract class GoogleAuth {
  /// False when this build has no OAuth client id for the platform.
  bool get isConfigured;

  /// Reconnects without any UI. Null means the user has to click Connect.
  Future<http.Client?> restore(Workspace ws, {String? email});

  /// Interactive sign-in. [email] pre-selects an account on reconnect.
  Future<http.Client> connect(Workspace ws, {String? email});

  /// Forgets (and where possible revokes) the workspace's credentials.
  Future<void> disconnect(Workspace ws, {String? email});
}

/// Adds a bearer token to every request.
class BearerClient extends http.BaseClient {
  BearerClient(this._token, {http.Client? inner, this.onUnauthorized})
    : _inner = inner ?? http.Client();

  final Future<String> Function() _token;
  final http.Client _inner;

  /// Lets the token source drop a cached token Google rejected.
  final Future<void> Function(String token)? onUnauthorized;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _token();
    request.headers['Authorization'] = 'Bearer $token';
    final response = await _inner.send(request);
    if (response.statusCode == 401) await onUnauthorized?.call(token);
    return response;
  }

  @override
  void close() => _inner.close();
}
