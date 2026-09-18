import 'package:test/test.dart';
import 'package:tongtong_server/tongtong_server.dart';

void main() {
  group('ManualClock', () {
    test('starts at injected time, not wall time', () {
      final clock = ManualClock(startMs: 5000);
      expect(clock(), 5000);
    });

    test('advanceMs steps time by exact amounts', () {
      final clock = ManualClock(startMs: 100);
      expect((clock..advanceMs(9999))(), 10099);
      expect((clock..advanceMs(1))(), 10100);
    });
  });
}
