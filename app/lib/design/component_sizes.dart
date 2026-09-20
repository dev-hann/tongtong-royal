/// Component-size tokens for TongTong Royal.
///
/// Fixed dimensions of shared UI parts that are component geometry,
/// not flow spacing (guide § 6 — "avatars use the tokenized size").
/// No raw 96/56 literals in screens. Re-exported through
/// `design/tokens.dart` (ArenaPalette precedent) so screens import
/// one token library.
abstract final class ComponentSizes {
  /// Avatar circle diameter on the profile/onboarding identity cards.
  static const double avatar = 96;

  /// Home corner entry button (avatar / settings gear) — thumb-sized
  /// circular target, SafeArea-protected corners (guide § 6 Home).
  static const double homeEntry = 56;

  /// Icon glyph inside home corner entries (24 = rows per § 2.1,
  /// 28 = home entries per § 2.1 — kept as tokens, not literals).
  static const double homeEntryIcon = 28;

  /// Row-level icon glyph (§ 2.1 size 24 role: verdict rows, list
  /// rows).
  static const double rowIcon = 24;

  /// Hero-moment icon glyph (§ 2.1 size 32+ role: crown reveals,
  /// podium ceremony).
  static const double heroIcon = 40;
}
