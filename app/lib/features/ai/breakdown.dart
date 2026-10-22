/// "Break this down": asks Claude to split a task into small steps, using
/// the user's own Anthropic API key. Optional; the app works without it.
///
/// Only the task's title, notes and estimate are sent. Callers must run the
/// PHI check first for Work tasks (see `BreakdownService`).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

const aiModel = 'claude-opus-5-5';
const _endpoint = 'https://api.anthropic.com/v1/messages';

/// Most steps we'll add from one answer.
const maxAiSteps = 10;

class BreakdownException implements Exception {
  const BreakdownException(this.message);

  /// Plain words for a snackbar.
  final String message;

  @override
  String toString() => message;
}

const _system =
    'You break one task into small, concrete steps for someone with ADHD '
    'who finds it hard to start. The first step must take under two '
    'minutes and be an obvious physical action (open, find, write down). '
    'Give 3 to 7 steps, in order, each an imperative under 12 words, with '
    'no numbering. Only include steps the task actually needs: no breaks, '
    'rewards or pep talk.';

Map<String, Object?> breakdownRequest({
  required String title,
  String notes = '',
  int? estimateMin,
}) => {
  'model': aiModel,
  'max_tokens': 16000,
  // Opus 5.5 always thinks; a small task needs only a little of it.
  'output_config': {
    'effort': 'low',
    'format': {
      'type': 'json_schema',
      'schema': {
        'type': 'object',
        'properties': {
          'steps': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'required': ['steps'],
        'additionalProperties': false,
      },
    },
  },
  // On a safety decline, let the API retry on its recommended model.
  'fallbacks': 'default',
  'system': _system,
  'messages': [
    {
      'role': 'user',
      'content': [
        'Task: ${title.trim()}',
        if (notes.trim().isNotEmpty) 'Notes: ${notes.trim()}',
        if (estimateMin != null) 'Rough length: $estimateMin minutes',
      ].join('\n'),
    },
  ],
};

/// The steps from a Messages API response body.
List<String> stepsFromResponse(Map<String, Object?> body) {
  if (body['stop_reason'] == 'refusal') {
    throw const BreakdownException(
      'Claude declined to break this one down. Try rewording the task.',
    );
  }
  final content = body['content'];
  if (content is! List) {
    throw const BreakdownException('Claude sent back something unexpected.');
  }
  // Thinking blocks may come first; the answer is the text block.
  final text = content
      .whereType<Map<String, Object?>>()
      .where((b) => b['type'] == 'text')
      .map((b) => b['text'])
      .whereType<String>()
      .firstOrNull;
  if (text == null) {
    throw const BreakdownException('Claude sent back something unexpected.');
  }
  try {
    final steps = (jsonDecode(text) as Map<String, Object?>)['steps'];
    final list = [
      for (final s in steps as List)
        if (s is String && s.trim().isNotEmpty)
          s.trim().replaceAll(RegExp(r'\s+'), ' '),
    ];
    if (list.isEmpty) throw const FormatException();
    return list.take(maxAiSteps).toList();
  } on Object {
    throw const BreakdownException('Claude sent back something unexpected.');
  }
}

/// Calls the API. Throws [BreakdownException] with a readable message.
Future<List<String>> requestBreakdown({
  required http.Client client,
  required String apiKey,
  required String title,
  String notes = '',
  int? estimateMin,
}) async {
  final http.Response res;
  try {
    res = await client
        .post(
          Uri.parse(_endpoint),
          headers: {
            'content-type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'anthropic-beta': 'server-side-fallback-2026-07-01',
            // Needed when the web app calls the API straight from the
            // browser. The key is the user's own and stays on their device.
            'anthropic-dangerous-direct-browser-access': 'true',
          },
          body: jsonEncode(
            breakdownRequest(
              title: title,
              notes: notes,
              estimateMin: estimateMin,
            ),
          ),
        )
        .timeout(const Duration(seconds: 90));
  } on Object {
    throw const BreakdownException(
      "Couldn't reach Anthropic. Check your connection and try again.",
    );
  }
  switch (res.statusCode) {
    case 200:
      break;
    case 401 || 403:
      throw const BreakdownException(
        "That API key didn't work. Check it in Settings → AI helper.",
      );
    case 402:
      throw const BreakdownException(
        'Your Anthropic account needs credit. Add some at '
        'console.anthropic.com.',
      );
    case 429:
      throw const BreakdownException(
        'Too many requests right now. Try again in a minute.',
      );
    case >= 500:
      throw const BreakdownException(
        'Claude is busy right now. Try again in a minute.',
      );
    default:
      throw BreakdownException(
        'Claude couldn\'t do that one (error ${res.statusCode}).',
      );
  }
  try {
    return stepsFromResponse(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, Object?>,
    );
  } on BreakdownException {
    rethrow;
  } on Object {
    throw const BreakdownException('Claude sent back something unexpected.');
  }
}
