import 'dart:convert';

import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/ai/ai_settings.dart';
import 'package:adhd_tax/features/ai/breakdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> _answer(List<String> steps, {String stop = 'end_turn'}) =>
    {
      'stop_reason': stop,
      'content': [
        {'type': 'thinking', 'thinking': ''},
        {
          'type': 'text',
          'text': jsonEncode({'steps': steps}),
        },
      ],
    };

void main() {
  test(
    'sends title, notes and length with the right headers and schema',
    () async {
      late http.Request sent;
      final client = MockClient((req) async {
        sent = req;
        return http.Response(
          jsonEncode(_answer(['Open the portal', 'Log in'])),
          200,
        );
      });
      final steps = await requestBreakdown(
        client: client,
        apiKey: 'sk-test',
        title: 'Renew license',
        notes: 'need photo',
        estimateMin: 30,
      );
      expect(steps, ['Open the portal', 'Log in']);
      expect(sent.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(sent.headers['x-api-key'], 'sk-test');
      expect(sent.headers['anthropic-version'], '2023-06-01');
      expect(sent.headers['anthropic-dangerous-direct-browser-access'], 'true');
      final body = jsonDecode(sent.body) as Map<String, Object?>;
      expect(body['model'], aiModel);
      expect(body['fallbacks'], 'default');
      final user =
          ((body['messages'] as List).single as Map)['content'] as String;
      expect(user, contains('Renew license'));
      expect(user, contains('need photo'));
      expect(user, contains('30 minutes'));
      final format = (body['output_config'] as Map)['format'] as Map;
      expect(format['type'], 'json_schema');
    },
  );

  test('tidies steps and caps how many are added', () {
    final many = [for (var i = 0; i < 15; i++) '  Step   $i '];
    final steps = stepsFromResponse(_answer(['', ...many]));
    expect(steps, hasLength(maxAiSteps));
    expect(steps.first, 'Step 0');
  });

  test('refusals and HTTP errors become plain messages', () async {
    expect(
      () => stepsFromResponse(_answer([], stop: 'refusal')),
      throwsA(isA<BreakdownException>()),
    );
    for (final (code, words) in [
      (401, 'API key'),
      (429, 'Too many'),
      (529, 'busy'),
      (402, 'credit'),
    ]) {
      final client = MockClient((_) async => http.Response('{}', code));
      await expectLater(
        requestBreakdown(client: client, apiKey: 'k', title: 't'),
        throwsA(
          isA<BreakdownException>().having(
            (e) => e.message,
            'message',
            contains(words),
          ),
        ),
      );
    }
    final offline = MockClient(
      (_) async => throw http.ClientException('no net'),
    );
    await expectLater(
      requestBreakdown(client: offline, apiKey: 'k', title: 't'),
      throwsA(
        isA<BreakdownException>().having(
          (e) => e.message,
          'm',
          contains("Couldn't reach"),
        ),
      ),
    );
  });

  test('what may be sent: key needed, Work only when allowed, no PHI', () {
    const none = AiSettings();
    const keyOnly = AiSettings(key: 'k');
    const work = AiSettings(key: 'k', allowWork: true);
    expect(
      aiBlockReason(settings: none, workspace: Workspace.personal, text: 'x'),
      contains('API key'),
    );
    expect(
      aiBlockReason(
        settings: keyOnly,
        workspace: Workspace.personal,
        text: 'x',
      ),
      isNull,
    );
    expect(
      aiBlockReason(settings: keyOnly, workspace: Workspace.work, text: 'x'),
      contains('off for Work'),
    );
    expect(
      aiBlockReason(
        settings: work,
        workspace: Workspace.work,
        text: 'Order toner',
      ),
      isNull,
    );
    expect(
      aiBlockReason(
        settings: work,
        workspace: Workspace.work,
        text: 'Call pt John Smith re: refill',
      ),
      contains('personal details'),
    );
  });
}
