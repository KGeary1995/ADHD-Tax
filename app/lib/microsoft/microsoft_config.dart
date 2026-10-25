/// The Microsoft app registration's client id, supplied at build time like
/// the Google ones (google_oauth.json, `--dart-define-from-file`). It's a
/// public client: there is no secret, and PKCE protects the sign-in.
///
/// See README → "Set up OneDrive sync" for the Entra app registration.
library;

class MicrosoftConfig {
  static const clientId = String.fromEnvironment('MICROSOFT_CLIENT_ID');

  /// `common`: personal Microsoft accounts and work or school accounts.
  static const authority =
      'https://login.microsoftonline.com/common/oauth2/v2.0';

  /// The app's own folder in OneDrive (Apps/Gumption) and nothing else;
  /// User.Read only to show which account is connected; offline_access
  /// for a refresh token.
  static const scopes = 'Files.ReadWrite.AppFolder User.Read offline_access';

  /// Android returns from the browser through this link (MainActivity's
  /// intent filter). Everywhere else uses a loopback address.
  static const androidRedirect = 'gumption://auth';
}
