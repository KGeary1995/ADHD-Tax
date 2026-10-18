/// OAuth client ids, supplied at build time so they never live in the repo:
///
///   flutter run --dart-define-from-file=google_oauth.json
///
/// See google_oauth.example.json and the README for how to create them.
library;

class GoogleConfig {
  /// "Web application" client. Used by the web build, and by Android as the
  /// server client id that Google Sign-In requires.
  static const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// "iOS" client for iPhone and iPad. Its reversed id must also be a URL
  /// scheme in ios/Runner/Info.plist; CI adds it (see ci.yml, "ios").
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  /// "Desktop app" client for Windows, macOS and Linux. Google documents
  /// that installed-app secrets aren't confidential; PKCE protects the flow.
  static const desktopClientId = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_ID',
  );
  static const desktopClientSecret = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_SECRET',
  );

  /// Both are Google's "non-sensitive" Drive scopes: the app sees only its
  /// own hidden sync folder and files it creates (backups), never the rest
  /// of the user's Drive.
  static const scopes = [
    'https://www.googleapis.com/auth/drive.appdata',
    'https://www.googleapis.com/auth/drive.file',
  ];
}
