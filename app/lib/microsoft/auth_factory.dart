export 'auth_unsupported.dart'
    if (dart.library.io) 'auth_io.dart'
    if (dart.library.js_interop) 'auth_web.dart';
