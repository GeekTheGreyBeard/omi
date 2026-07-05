import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:omi/backend/http/api/conversations.dart';

Map<String, dynamic> _conversationJson(String id) {
  return {
    'id': id,
    'created_at': '2026-06-27T12:00:00Z',
    'structured': {
      'title': 'Conversation $id',
      'overview': 'Overview $id',
      'emoji': '',
      'category': 'other',
    },
    'transcript_segments': [],
    'apps_results': [],
    'suggested_summarization_apps': [],
    'audio_files': [],
    'source': 'splati-preproduction',
    'status': 'completed',
  };
}

void main() {
  group('parseConversationsResponseBody', () {
    test('accepts the normal bare-list response', () {
      final conversations = parseConversationsResponseBody(jsonEncode([_conversationJson('one')]));

      expect(conversations, hasLength(1));
      expect(conversations.single.id, 'one');
    });

    test('accepts Android-compatible envelopes', () {
      final conversations = parseConversationsResponseBody(
        jsonEncode({
          'conversations': [_conversationJson('one'), _conversationJson('two')],
        }),
      );

      expect(conversations.map((conversation) => conversation.id), ['one', 'two']);
    });

    test('skips malformed items instead of dropping the whole page', () {
      final conversations = parseConversationsResponseBody(
        jsonEncode([
          _conversationJson('good'),
          {'id': 'bad'},
        ]),
      );

      expect(conversations, hasLength(1));
      expect(conversations.single.id, 'good');
    });
  });
}
