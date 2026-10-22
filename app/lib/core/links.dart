/// Public pages that ship with the web build (`web/privacy/`,
/// `web/support/`). The store listings and Google's sign-in screen link to
/// the same addresses, so change them together if the app gets a domain.
abstract final class Links {
  static const site = 'https://unstuck-4o8.pages.dev';
  static const privacy = '$site/privacy/';
  static const support = '$site/support/';
  static const terms = '$site/terms/';
}
