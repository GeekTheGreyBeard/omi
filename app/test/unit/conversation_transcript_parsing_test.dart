import 'package:flutter_test/flutter_test.dart';

import 'package:omi/backend/schema/conversation.dart';
import 'package:omi/backend/schema/transcript_segment.dart';

Map<String, dynamic> _conversationJson(Map<String, dynamic> overrides) {
  return {
    'id': 'conversation-1',
    'created_at': '2026-06-27T12:00:00Z',
    'structured': {
      'title': 'Transcript test',
      'overview': 'Overview',
      'emoji': '',
      'category': 'other',
    },
    'apps_results': [],
    'suggested_summarization_apps': [],
    'audio_files': [],
    ...overrides,
  };
}

void main() {
  group('ServerConversation transcript parsing', () {
    test('parses normal transcript_segments and assigns indexes', () {
      final conversation = ServerConversation.fromJson(
        _conversationJson({
          'transcript_segments': [
            {
              'id': 'segment-1',
              'text': 'Hello from Android',
              'speaker': 'SPEAKER_00',
              'is_user': true,
              'start': 1,
              'end': 2,
            },
          ],
        }),
      );

      expect(conversation.transcriptSegments, hasLength(1));
      expect(conversation.transcriptSegments.first.text, 'Hello from Android');
      expect(conversation.transcriptSegments.first.idx, 0);
    });

    test('parses camelCase transcriptSegments from backend-compatible payloads', () {
      final conversation = ServerConversation.fromJson(
        _conversationJson({
          'transcriptSegments': [
            {
              'id': 'segment-1',
              'transcript': 'Visible transcript text',
              'speaker_id': 1,
              'is_user': false,
              'start': '3.5',
              'end': '5.0',
            },
          ],
        }),
      );

      final segment = conversation.transcriptSegments.single;
      expect(segment.text, 'Visible transcript text');
      expect(segment.speaker, 'SPEAKER_01');
      expect(segment.speakerId, 1);
      expect(segment.start, 3.5);
      expect(segment.end, 5.0);
    });

    test('falls back to plain transcript text when no segment list is present', () {
      final conversation = ServerConversation.fromJson(
        _conversationJson({
          'transcript_text': 'This transcript came back as a plain string.',
        }),
      );

      expect(conversation.transcriptSegments, hasLength(1));
      expect(conversation.transcriptSegments.first.text, 'This transcript came back as a plain string.');
      expect(conversation.getTranscript(), contains('This transcript came back as a plain string.'));
    });
  });

  group('TranscriptSegment parsing', () {
    test('accepts content text alias and string booleans', () {
      final segment = TranscriptSegment.fromJson({
        'id': 'segment-1',
        'content': 'Segment content',
        'speaker_id': 2,
        'is_user': 'true',
        'speech_profile_processed': 'false',
        'start': 0,
        'end': 1,
      });

      expect(segment.text, 'Segment content');
      expect(segment.speaker, 'SPEAKER_02');
      expect(segment.isUser, isTrue);
      expect(segment.speechProfileProcessed, isFalse);
    });
  });
}
