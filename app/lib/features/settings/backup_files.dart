import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'web_share_stub.dart' if (dart.library.js_interop) 'web_share.dart';

/// Where backup files go and come from: the system save and open dialogs.
/// Tests override [backupFilesProvider] with a fake.
abstract class BackupFiles {
  /// Returns false if the user cancelled.
  Future<bool> save(String name, String json);

  /// The picked file's text, or null if the user cancelled.
  Future<String?> open();
}

final backupFilesProvider = Provider<BackupFiles>((ref) => PickerBackupFiles());

class PickerBackupFiles implements BackupFiles {
  @override
  Future<bool> save(String name, String json) async {
    final bytes = Uint8List.fromList(utf8.encode(json));
    // In a browser (the iPhone home-screen app), the share sheet offers
    // Save to Files, Drive and Mail; a plain download is easy to lose.
    if (await shareFileOnWeb(name, bytes) case final shared?) return shared;
    final uri = await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: 'Save Gumption backup',
    );
    // The browser download fallback returns null without a dialog.
    return uri != null || isWeb;
  }

  @override
  Future<String?> open() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose a Gumption backup',
    );
    if (file == null) return null;
    return utf8.decode(await file.readAsBytes(), allowMalformed: true);
  }
}
