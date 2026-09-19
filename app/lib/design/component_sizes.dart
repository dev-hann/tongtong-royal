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
}
