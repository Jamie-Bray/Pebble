import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/share/shared_routine_link.dart';

void main() {
  const routine = SharedRoutine(
    title: 'House sitter handover',
    steps: [
      RoutineStep.check(label: 'Water the plants', allowSkip: true),
      RoutineStep.info(message: 'Spare key is under the blue pot'),
      RoutineStep.check(
        label: 'Lock the back door',
        requiresPhoto: true,
        photoPrompt: 'Show the handle',
      ),
      RoutineStep.timer(duration: 300),
    ],
  );

  test('a link round-trips the title and steps', () {
    final link = routine.toLink();
    expect(link.scheme, 'https');
    expect(link.host, 'pebbleroutines.com');
    expect(link.path, '/r');
    expect(link.toString(), isNot(contains('=')));

    final back = SharedRoutine.fromLink(link)!;
    expect(back.title, 'House sitter handover');
    expect(back.steps, const [
      RoutineStep.check(label: 'Water the plants', allowSkip: true),
      RoutineStep.info(message: 'Spare key is under the blue pot'),
      // The photo prompt stays on the sender's phone.
      RoutineStep.check(label: 'Lock the back door', requiresPhoto: true),
      RoutineStep.timer(duration: 300),
    ]);
  });

  test('links are compressed, and older uncompressed links still open', () {
    expect(routine.data, startsWith('z'));
    final plain = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'v': 1,
              't': 'House sitter handover',
              's': [
                {'c': 'Water the plants', 'k': 1},
                {'i': 'Spare key is under the blue pot'},
              ],
            }),
          ),
        )
        .replaceAll('=', '');
    expect(routine.data.length, lessThan(plain.length + 60));
    final old = SharedRoutine.fromLink(
      Uri.parse('https://pebbleroutines.com/r#$plain'),
    );
    expect(
      old?.steps.first,
      const RoutineStep.check(label: 'Water the plants', allowSkip: true),
    );
  });

  test('a link that inflates into megabytes is refused', () {
    final bomb = ZLibCodec(raw: true, level: 9).encode(
      utf8.encode('{"v":1,"t":"${'a' * (2 * 1024 * 1024)}","s":[{"c":"x"}]}'),
    );
    final data = 'z${base64Url.encode(bomb).replaceAll('=', '')}';
    expect(data.length, lessThan(8 * 1024));
    expect(SharedRoutine.fromData(data), isNull);
  });

  test('the app link from the web page reads the same', () {
    final app = Uri.parse('pebbleroutines://r#${routine.data}');
    expect(SharedRoutine.fromLink(app)?.steps, hasLength(4));
  });

  test('guidance audio is never put in a link', () {
    const withAudio = SharedRoutine(
      title: 'Morning',
      steps: [
        RoutineStep.check(
          label: 'Meds',
          guidanceAudio: StepGuidanceAudio(
            localPath: 'audio/meds.m4a',
            durationMs: 2000,
          ),
        ),
      ],
    );
    final json = utf8.decode(
      ZLibCodec(raw: true).decode(
        base64Url.decode(base64Url.normalize(withAudio.data.substring(1))),
      ),
    );
    expect(json, contains('Meds'));
    expect(json, isNot(contains('audio')));
  });

  test('other links are not shared routines', () {
    for (final link in [
      'https://pebbleroutines.com/privacy#x',
      'https://example.com/r#${routine.data}',
      'pebble://play/12',
      'com.googleusercontent.apps.123:/oauth#code=1',
    ]) {
      expect(SharedRoutine.fromLink(Uri.parse(link)), isNull, reason: link);
    }
  });

  group('a damaged or hostile link', () {
    String encode(Object payload) =>
        base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');

    test('missing or garbled data reads as null', () {
      expect(SharedRoutine.fromData(''), isNull);
      expect(SharedRoutine.fromData('not-base64!!'), isNull);
      expect(SharedRoutine.fromData(encode([1, 2])), isNull);
      expect(
        SharedRoutine.fromData(encode({'v': 2, 't': 'x', 's': []})),
        isNull,
      );
    });

    test('a routine with no checks reads as null', () {
      expect(
        SharedRoutine.fromData(
          encode({
            'v': 1,
            't': 'Notes only',
            's': [
              {'i': 'hello'},
            ],
          }),
        ),
        isNull,
      );
    });

    test('long text is capped, control characters dropped, steps limited', () {
      final shared = SharedRoutine.fromData(
        encode({
          'v': 1,
          't': 'A' * 500,
          's': [
            {'c': 'Line\u0000one\nand two'},
            {'w': -5},
            {'w': 999999},
            {'c': ''},
            {'x': 'unknown'},
            for (var i = 0; i < 100; i++) {'c': 'Step $i'},
          ],
        }),
      )!;
      expect(shared.title.length, SharedRoutine.maxTitleChars);
      expect(
        shared.steps.first,
        const RoutineStep.check(label: 'Line one and two'),
      );
      expect(shared.steps.whereType<TimerStep>(), isEmpty);
      expect(shared.steps.length, lessThanOrEqualTo(SharedRoutine.maxSteps));
    });

    test('an empty title reads as "Shared routine"', () {
      final shared = SharedRoutine.fromData(
        encode({
          'v': 1,
          't': '  ',
          's': [
            {'c': 'One'},
          ],
        }),
      );
      expect(shared?.title, 'Shared routine');
    });
  });
}
