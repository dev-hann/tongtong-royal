import 'package:test/test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  group('checkVersion', () {
    test('current version N is ok', () {
      expect(checkVersion(protocolVersion), VersionStatus.ok);
    });

    test('previous version N-1 is ok', () {
      expect(checkVersion(protocolVersion - 1), VersionStatus.ok);
    });

    test('N-2 is clientTooOld', () {
      expect(checkVersion(protocolVersion - 2), VersionStatus.clientTooOld);
    });

    test('N+1 is serverTooOld', () {
      expect(checkVersion(protocolVersion + 1), VersionStatus.serverTooOld);
    });

    test('very old client is clientTooOld', () {
      expect(checkVersion(-5), VersionStatus.clientTooOld);
    });

    test('very new client is serverTooOld', () {
      expect(checkVersion(999), VersionStatus.serverTooOld);
    });
  });

  test('protocolVersion starts at 1', () {
    expect(protocolVersion, 1);
  });
}
