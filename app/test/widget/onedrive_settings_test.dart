import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/google/google_auth.dart';
import 'package:adhd_tax/sync/remote_store.dart';
import 'package:adhd_tax/sync/sync_controller.dart';
import 'package:adhd_tax/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../sync/fake_remote.dart';
import 'app_flow_test.dart' show openSettings, pumpApp;

const _phone = Size(390, 844);

class _OneDrive implements AccountRemoteStore {
  _OneDrive(this.folder);
  final FakeRemote folder;
  @override
  Future<String?> accountEmail() async => 'kyle@outlook.com';
  @override
  Future<String?> exportBackup(String name, List<int> bytes) async => null;
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

/// A sign-in that's configured and, for Microsoft, finishes at once.
class _Auth implements GoogleAuth {
  _Auth({this.finishes = false});
  final bool finishes;
  final connected = <Workspace>[];
  @override
  bool get isConfigured => true;
  @override
  bool get restoreMayRecover => false;
  @override
  Future<http.Client> connect(Workspace ws, {String? email}) async {
    if (!finishes) throw UnimplementedError();
    connected.add(ws);
    return MockClient((_) async => http.Response('{}', 200));
  }

  @override
  Future<http.Client?> restore(Workspace ws, {String? email}) async => null;
  @override
  Future<void> disconnect(Workspace ws, {String? email}) async {}
}

void main() {
  testWidgets('Connect offers Google or Microsoft; OneDrive connects and the '
      'row says which service it uses', (tester) async {
    final folder = FakeRemote();
    final ms = _Auth(finishes: true);
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [
        googleAuthProvider.overrideWithValue(_Auth()),
        iCloudSupportedProvider.overrideWithValue(false),
        microsoftAuthProvider.overrideWithValue(ms),
        oneDriveFactoryProvider.overrideWithValue((_) => _OneDrive(folder)),
      ],
    );
    await openSettings(tester);
    await tester.dragUntilVisible(
      find
          .text(
            'Not connected. Sync with a Google account or a Microsoft '
            'account.',
          )
          .first,
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect').first);
    await tester.pumpAndSettle();
    expect(find.text('Sync Personal with…'), findsOneWidget);
    expect(find.widgetWithText(SheetChoice, 'iCloud'), findsNothing);
    expect(find.widgetWithText(SheetChoice, 'Google account'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(SheetChoice, 'Microsoft account (OneDrive)'),
    );
    await tester.pumpAndSettle();

    expect(ms.connected, [Workspace.personal]);
    expect(find.textContaining('OneDrive · kyle@outlook.com'), findsOneWidget);
    expect(folder.files, isNotEmpty);
    expect(tester.takeException(), isNull);
    await c.read(syncProvider(Workspace.personal).notifier).disconnect();
    await tester.pumpAndSettle();
  });

  testWidgets('with only Microsoft set up, Connect goes straight to it', (
    tester,
  ) async {
    final ms = _Auth(finishes: true);
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [
        iCloudSupportedProvider.overrideWithValue(false),
        microsoftAuthProvider.overrideWithValue(ms),
        oneDriveFactoryProvider.overrideWithValue(
          (_) => _OneDrive(FakeRemote()),
        ),
      ],
    );
    await openSettings(tester);
    await tester.dragUntilVisible(
      find.text('Connect').first,
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect').first);
    await tester.pumpAndSettle();
    expect(find.text('Sync Personal with…'), findsNothing);
    expect(ms.connected, [Workspace.personal]);
    // The note under the rows describes OneDrive, not Google.
    expect(find.textContaining('Apps/Gumption folder'), findsOneWidget);
    expect(find.textContaining('Google'), findsNothing);
    await c.read(syncProvider(Workspace.personal).notifier).disconnect();
    await tester.pumpAndSettle();
  });
}
