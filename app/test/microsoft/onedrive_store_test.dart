import 'dart:convert';

import 'package:adhd_tax/microsoft/onedrive_store.dart';
import 'package:adhd_tax/sync/account_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _root = 'https://graph.microsoft.com/v1.0/me/drive/special/approot';

http.Response _ok(Object body) => http.Response(jsonEncode(body), 200);

void main() {
  test('an account with no Sync folder yet lists nothing', () async {
    final store = OneDriveStore(
      MockClient(
        (r) async => http.Response('{"error":{"code":"itemNotFound"}}', 404),
      ),
    );
    expect(await store.list('state.'), isEmpty);
  });

  test('lists sync files across pages, by prefix, with cTag as the '
      'checksum', () async {
    final seen = <Uri>[];
    final store = OneDriveStore(
      MockClient((r) async {
        seen.add(r.url);
        if (r.url.path.endsWith('/children')) {
          return _ok({
            'value': [
              {
                'id': 'a',
                'name': 'state.personal.p1.json',
                'file': {},
                'cTag': 'c1',
              },
              {'id': 'b', 'name': 'notes.txt', 'file': {}, 'cTag': 'c2'},
              {'id': 'c', 'name': 'state.personal.folder', 'folder': {}},
            ],
            '@odata.nextLink': 'https://graph.microsoft.com/v1.0/next-page',
          });
        }
        return _ok({
          'value': [
            {
              'id': 'd',
              'name': 'state.personal.p2.json',
              'file': {},
              'cTag': 'c3',
            },
          ],
        });
      }),
    );
    final files = await store.list('state.personal.');
    expect(files.map((f) => (f.id, f.name, f.checksum)), [
      ('a', 'state.personal.p1.json', 'c1'),
      ('d', 'state.personal.p2.json', 'c3'),
    ]);
    expect(seen.first.toString(), startsWith('$_root:/Sync:/children'));
    expect(seen.last.path, '/v1.0/next-page');
  });

  test(
    'reads through the pre-signed download link, without the sign-in',
    () async {
      final signed = <String>[];
      final store = OneDriveStore(
        MockClient((r) async {
          signed.add(r.url.toString());
          return _ok({
            'id': 'a',
            '@microsoft.graph.downloadUrl': 'https://files.example/a?sig=1',
          });
        }),
        download: MockClient((r) async {
          expect(r.url.host, 'files.example');
          return http.Response.bytes(utf8.encode('{"x":1}'), 200);
        }),
      );
      expect(utf8.decode(await store.read('a')), '{"x":1}');
      expect(signed.single, contains('/me/drive/items/a?'));
    },
  );

  test('creates in Sync/ and updates by id', () async {
    final puts = <String>[];
    final store = OneDriveStore(
      MockClient((r) async {
        expect(r.method, 'PUT');
        puts.add(r.url.toString());
        return _ok({'id': 'new-id'});
      }),
    );
    expect(await store.create('state.work.d1.json', [1, 2]), 'new-id');
    await store.update('new-id', [3]);
    expect(puts, [
      '$_root:/Sync/state.work.d1.json:/content',
      'https://graph.microsoft.com/v1.0/me/drive/items/new-id/content',
    ]);
  });

  test(
    'a file over 4 MB goes up in pieces through an upload session',
    () async {
      final bytes = List.filled(OneDriveStore.chunk * 2 + 10, 7);
      final ranges = <String>[];
      final store = OneDriveStore(
        MockClient((r) async {
          expect(r.url.path, endsWith('/createUploadSession'));
          return _ok({'uploadUrl': 'https://upload.example/s1'});
        }),
        download: MockClient((r) async {
          ranges.add(r.headers['Content-Range']!);
          final done = ranges.length == 3;
          return http.Response(
            done ? jsonEncode({'id': 'big'}) : '{}',
            done ? 201 : 202,
          );
        }),
      );
      expect(await store.create('state.personal.d1.json', bytes), 'big');
      final c = OneDriveStore.chunk, n = bytes.length;
      expect(ranges, [
        'bytes 0-${c - 1}/$n',
        'bytes $c-${2 * c - 1}/$n',
        'bytes ${2 * c}-${n - 1}/$n',
      ]);
    },
  );

  test('the account is its mail, or its sign-in name', () async {
    var me = <String, Object?>{'mail': 'kyle@contoso.com'};
    final store = OneDriveStore(MockClient((r) async => _ok(me)));
    expect(await store.accountEmail(), 'kyle@contoso.com');
    me = {'mail': null, 'userPrincipalName': 'kyle@outlook.com'};
    expect(await store.accountEmail(), 'kyle@outlook.com');
  });

  test('backups go to Backups/ and return their web link', () async {
    final store = OneDriveStore(
      MockClient((r) async {
        expect(r.url.toString(), contains(':/Backups/Gumption%20backup.json:'));
        return _ok({'id': 'b', 'webUrl': 'https://onedrive.example/b'});
      }),
    );
    expect(
      await store.exportBackup('Gumption backup.json', [1]),
      'https://onedrive.example/b',
    );
  });

  test('401 asks to reconnect; 403 explains a blocked work account', () async {
    var status = 401;
    final store = OneDriveStore(
      MockClient((r) async => http.Response('{}', status)),
    );
    await expectLater(store.list(''), throwsA(isA<NeedsReconnect>()));
    status = 403;
    await expectLater(
      store.list(''),
      throwsA(
        isA<OneDriveError>().having(
          (e) => e.toString(),
          'message',
          contains('admin'),
        ),
      ),
    );
  });
}
