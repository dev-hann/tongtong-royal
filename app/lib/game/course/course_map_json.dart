part of 'course_map.dart';

/// JSON codec for [CourseMap] (kept in a part to respect the
/// 300-line file limit, docs/05 § Limits).
final class CourseMapJson {
  /// Parses [json] into a [CourseMap].
  static CourseMap fromJson(Map<String, Object?> json) {
    Object? field(String name) {
      final value = json[name];
      if (value == null) {
        throw FormatException('CourseMap.$name is missing');
      }
      return value;
    }

    Vector2 point(Object? value, String name) {
      if (value is! List || value.length != 2) {
        throw FormatException('CourseMap.$name must be [x, y]');
      }
      return Vector2(
        (value[0] as num).toDouble(),
        (value[1] as num).toDouble(),
      );
    }

    List<T> list<T>(Object? value, String name, T Function(Object?) parse) {
      if (value is! List) {
        throw FormatException('CourseMap.$name must be a list');
      }
      return [for (final item in value) parse(item)];
    }

    return CourseMap(
      mapSeed: field('mapSeed')! as int,
      spawnPoint: point(field('spawnPoint'), 'spawnPoint'),
      checkpoints: list<Vector2>(
        field('checkpoints'),
        'checkpoints',
        (item) => point(item, 'checkpoints'),
      ),
      finishLine: BoxSpec.fromJson(_asObject(field('finishLine'))),
      killY: (field('killY')! as num).toDouble(),
      platforms: list(
        field('platforms'),
        'platforms',
        (item) => BoxSpec.fromJson(_asObject(item)),
      ),
      walls: list(
        field('walls'),
        'walls',
        (item) => BoxSpec.fromJson(_asObject(item)),
      ),
      hammers: list(
        field('hammers'),
        'hammers',
        (item) => HammerSpec.fromJson(_asObject(item)),
      ),
      // Variant-only fields: absent on the standard course.
      spawnPoints: list<Vector2>(
        json['spawnPoints'] ?? const [],
        'spawnPoints',
        (item) => point(item, 'spawnPoints'),
      ),
      movingWalls: list(
        json['movingWalls'] ?? const [],
        'movingWalls',
        (item) => MovingWallSpec.fromJson(_asObject(item)),
      ),
    );
  }

  static Map<String, Object?> _asObject(Object? value) {
    if (value is! Map) {
      throw const FormatException('expected a JSON object');
    }
    return value.map((k, v) => MapEntry(k as String, v));
  }
}
