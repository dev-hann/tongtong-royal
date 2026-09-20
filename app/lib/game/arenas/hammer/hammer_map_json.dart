part of 'hammer_map.dart';

/// JSON codec for [HammerArenaMap] (kept in a part to respect the
/// 300-line file limit, docs/05 § Limits).
final class HammerArenaMapJson {
  /// Parses [json] into a [HammerArenaMap].
  static HammerArenaMap fromJson(Map<String, Object?> json) {
    Object? field(String name) {
      final value = json[name];
      if (value == null) {
        throw FormatException('HammerArenaMap.$name is missing');
      }
      return value;
    }

    Vector2 point(Object? value, String name) {
      if (value is! List || value.length != 2) {
        throw FormatException('HammerArenaMap.$name must be [x, y]');
      }
      return Vector2(
        (value[0] as num).toDouble(),
        (value[1] as num).toDouble(),
      );
    }

    List<T> list<T>(Object? value, String name, T Function(Object?) parse) {
      if (value is! List) {
        throw FormatException('HammerArenaMap.$name must be a list');
      }
      return [for (final item in value) parse(item)];
    }

    final shrink = json['shrink'];
    if (shrink is! Map) {
      throw const FormatException('HammerArenaMap.shrink must be a map');
    }
    final slab = json['centerSlab'];
    if (slab is! Map) {
      throw const FormatException('HammerArenaMap.centerSlab must be a map');
    }

    return HammerArenaMap(
      mapSeed: field('mapSeed')! as int,
      platformRadius: HammerArenaMap._asDouble(
        field('platformRadius'),
        'platformRadius',
      ),
      platformSegmentCount:
          field('platformSegmentCount')! as int,
      platformThickness: HammerArenaMap._asDouble(
        field('platformThickness'),
        'platformThickness',
      ),
      killRingMargin: HammerArenaMap._asDouble(
        field('killRingMargin'),
        'killRingMargin',
      ),
      shrink: ShrinkSchedule.fromJson(
        shrink.map((k, v) => MapEntry(k as String, v)),
      ),
      centerSlab: BoxSpec.fromJson(
        slab.map((k, v) => MapEntry(k as String, v)),
      ),
      spawnPoints: list<Vector2>(
        field('spawnPoints'),
        'spawnPoints',
        (item) => point(item, 'spawnPoints'),
      ),
      hammers: list(
        field('hammers'),
        'hammers',
        (item) => HammerSpec.fromJson(HammerArenaMap._asObject(item)),
      ),
    );
  }
}
