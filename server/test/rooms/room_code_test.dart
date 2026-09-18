import 'dart:math';

import 'package:test/test.dart';
import 'package:tongtong_server/tongtong_server.dart';

import 'test_support.dart';

void main() {
  group('generateRoomCode', () {
    test('uses only allowed charset (no 0, O, 1, I) and 6 chars', () {
      final random = Random(42);
      final pattern = RegExp(r'^[A-HJ-NP-Z2-9]{6}$');
      for (var i = 0; i < 500; i++) {
        final code = generateRoomCode(random);
        expect(code, matches(pattern), reason: 'bad code: $code');
      }
    });

    test('deterministic for identical seed', () {
      final a = List.generate(5, (_) => generateRoomCode(Random(7)));
      final b = List.generate(5, (_) => generateRoomCode(Random(7)));
      expect(a, b);
    });

    test('follows the injected random source', () {
      final zero = SequencedRandom([0]);
      expect(generateRoomCode(zero), 'AAAAAA');
      final one = SequencedRandom([1]);
      expect(generateRoomCode(one), 'BBBBBB');
    });
  });
}
