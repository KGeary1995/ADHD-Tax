import 'dart:io' show Platform;

/// A real Android device (false in `flutter test`, which runs on the host).
bool get isAndroidDevice => Platform.isAndroid;
