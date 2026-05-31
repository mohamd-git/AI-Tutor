import 'package:flutter_test/flutter_test.dart';
import 'package:ai_tutor/services/voice.dart';

void main() {
  // The kind of pile-up the web recognizer produced in the bug report:
  // the phrase re-sent from the start, growing each time, all stuck together.
  const phrase =
      'hello can you explain for me the structured and structured and semester that';

  String growingPileup(String full, {int repeatEach = 1}) {
    final words = full.split(' ');
    final parts = <String>[];
    for (var k = 1; k <= words.length; k++) {
      for (var r = 0; r < repeatEach; r++) {
        parts.add(words.sublist(0, k).join(' '));
      }
    }
    return parts.join(' ');
  }

  test('collapses a growing pile-up to the final phrase', () {
    expect(collapseRepeatedSpeech(growingPileup(phrase)), phrase);
  });

  test('collapses a growing pile-up even when fragments repeat', () {
    expect(collapseRepeatedSpeech(growingPileup(phrase, repeatEach: 3)), phrase);
  });

  test('leaves a normal sentence unchanged', () {
    expect(collapseRepeatedSpeech('what is a cell'), 'what is a cell');
    expect(collapseRepeatedSpeech('the cat sat on the mat'),
        'the cat sat on the mat');
  });

  test('does not mangle a sentence that repeats its first word', () {
    expect(collapseRepeatedSpeech('is it good is it bad is it ugly'),
        'is it good is it bad is it ugly');
  });

  test('collapses an exact whole-phrase repeat', () {
    expect(collapseRepeatedSpeech('open the door open the door'), 'open the door');
  });

  test('keeps short genuine repeats', () {
    expect(collapseRepeatedSpeech('no no'), 'no no');
  });
}
