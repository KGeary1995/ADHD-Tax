import 'package:http/http.dart' as http;

import '../data/models/task.dart';
import 'google_auth.dart';

GoogleAuth createGoogleAuth() => _Unsupported();

class _Unsupported implements GoogleAuth {
  @override
  bool get isConfigured => false;

  @override
  bool get restoreMayRecover => false;

  @override
  Future<http.Client?> restore(Workspace ws, {String? email}) async => null;

  @override
  Future<http.Client> connect(Workspace ws, {String? email}) =>
      throw UnsupportedError('Google sign-in is not available here.');

  @override
  Future<void> disconnect(Workspace ws, {String? email}) async {}
}
