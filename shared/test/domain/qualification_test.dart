import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

void main() {
  test('result_exposes_ordered_qualified_and_eliminated', () {
    const result = QualificationResult(
      qualified: ['a', 'b'],
      eliminated: ['c'],
      isFinal: false,
    );

    expect(result.qualified, equals(['a', 'b']));
    expect(result.eliminated, equals(['c']));
  });

  test('champions_default_empty_and_stay_empty_when_not_final', () {
    const result = QualificationResult(
      qualified: ['a'],
      eliminated: ['b'],
      isFinal: false,
    );

    expect(result.champions, isEmpty);
    expect(result.isFinal, isFalse);
  });

  test('gdd_7_2_structure_supports_two_shared_champions', () {
    const result = QualificationResult(
      qualified: ['a', 'b'],
      eliminated: [],
      isFinal: true,
      champions: ['a', 'b'],
    );

    expect(result.isFinal, isTrue);
    expect(result.champions, hasLength(2));
  });

  test('equality_compares_all_fields', () {
    const a = QualificationResult(
      qualified: ['a'],
      eliminated: ['b'],
      isFinal: true,
      champions: ['a'],
    );
    const b = QualificationResult(
      qualified: ['a'],
      eliminated: ['b'],
      isFinal: true,
      champions: ['a'],
    );
    const c = QualificationResult(
      qualified: ['a'],
      eliminated: ['b'],
      isFinal: true,
      champions: ['b'],
    );

    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(equals(c)));
  });
}
