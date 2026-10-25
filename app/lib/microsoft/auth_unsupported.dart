import 'package:http/http.dart' as http;

import '../data/models/task.dart';
import '../sync/account_auth.dart';

/// The web build: OneDrive sync isn't offered there yet.
AccountAuth createMicrosoftAuth() => const _Unsupported();

class _Unsupported implements AccountAuth {
  const _Unsupported();

  @override
  bool get isConfigured => false;

  @override
  bool get restoreMayRecover => false;

  @override
  Future<http.Client?> restore(Workspace ws, {String? email}) async => null;

  @override
  Future<http.Client> connect(Workspace ws, {String? email}) =>
      throw UnsupportedError('OneDrive sync is not available here.');

  @override
  Future<void> disconnect(Workspace ws, {String? email}) async {}
}
