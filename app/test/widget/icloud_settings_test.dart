import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/google/google_auth.dart';
import 'package:adhd_tax/sync/remote_store.dart';
import 'package:adhd_tax/sync/sync_controller.dart';
import 'package:adhd_tax/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../sync/fake_remote.dart';
import 'app_flow_test.dart' show openSettings, pumpApp;

const _phone = Size(390, 844);

class _ICloud implements AccountRemoteStore {
  _ICloud(this.folder);
  final FakeRemote folder;
  @override
  Future<String?> accountEmail() async => 'icloud:a1b2c3';
  @override
  Future<String?> exportBackup(String name, List<int> bytes) =>
      throw UnsupportedError('no');
  @override
  Future<List<RemoteFile>> list(String prefix) => folder.list(prefix);
  @override
  Future<List<int>> read(String id) => folder.read(id);
  @override
  Future<String> create(String name, List<int> bytes) =>
      folder.create(name, bytes);
  @override
  Future<void> update(String id, List<int> bytes) => folder.update(id, bytes);
}

/// Google keys present, but the sign-in is never finished in these tests.
class _ConfiguredGoogle implements GoogleAuth {
  @override
  bool get isConfigured => true;
  @override
  bool get restoreMayRecover => false;
  @override
  Future<http.Client> connect(Workspace ws, {String? email}) =>
      throw UnimplementedError();
  @override
  Future<http.Client?> restore(Workspace ws, {String? email}) async => null;
  @override
  Future<void> disconnect(Workspace ws, {String? email}) async {}
}

Future<void> _showSync(WidgetTester tester) async {
  await openSettings(tester);
  await tester.dragUntilVisible(
    find.text('Not connected. Sync with iCloud or a Google account.').first,
    find.byType(Scrollable).first,
    const Offset(0, -300),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on iPhone, Connect offers iCloud or Google; iCloud connects '
      'with no sign-in and shows as "iCloud"', (tester) async {
    final folders = {for (final w in Workspace.values) w: FakeRemote()};
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [
        googleAuthProvider.overrideWithValue(_ConfiguredGoogle()),
        iCloudSupportedProvider.overrideWithValue(true),
        iCloudStoreProvider.overrideWithValue((ws) => _ICloud(folders[ws]!)),
      ],
    );
    await _showSync(tester);

    await tester.tap(find.text('Connect').first);
    await tester.pumpAndSettle();
    expect(find.text('Sync Personal with…'), findsOneWidget);
    expect(find.widgetWithText(SheetChoice, 'Google account'), findsOneWidget);
    await tester.tap(find.widgetWithText(SheetChoice, 'iCloud'));
    await tester.pumpAndSettle();

    expect(find.textContaining('iCloud · '), findsOneWidget);
    expect(find.textContaining('icloud:'), findsNothing);
    expect(folders[Workspace.personal]!.files, isNotEmpty);
    expect(tester.takeException(), isNull);
    // Stop the periodic sync before the test ends.
    await c.read(syncProvider(Workspace.personal).notifier).disconnect();
    await tester.pumpAndSettle();
  });

  testWidgets('elsewhere (no iCloud), Connect goes straight to Google', (
    tester,
  ) async {
    await pumpApp(
      tester,
      size: _phone,
      overrides: [
        googleAuthProvider.overrideWithValue(_ConfiguredGoogle()),
        iCloudSupportedProvider.overrideWithValue(false),
      ],
    );
    await openSettings(tester);
    await tester.dragUntilVisible(
      find.text('Connect').first,
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('iCloud'), findsNothing);
    await tester.tap(find.text('Connect').first);
    await tester.pumpAndSettle();
    expect(find.text('Sync Personal with…'), findsNothing);
  });
}
