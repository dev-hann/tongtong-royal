/// Phosphor Fill icon accessors (guide § 2.1).
///
/// `phosphor_flutter` 2.1.0 (latest release) subclasses `IconData`,
/// which is a `final class` on the pinned Flutter SDK — its Dart API
/// cannot compile. These constants declare the same glyph codepoints
/// as plain `IconData`s against the package's bundled `PhosphorFill`
/// font family, so the font ships via the package while its broken
/// Dart sources stay unimported.
library;

import 'package:flutter/widgets.dart' show IconData;

/// Phosphor Icons, Fill weight — rounded, chunky (guide § 2.1).
///
/// Sizes: 24 rows, 28 home entries, 32+ hero. Default color
/// `neutral700`; colors come from `Icon` call sites.
abstract final class TtrIcons {
  /// Settings gear.
  static const IconData gear = IconData(
    0xe270,
    fontFamily: 'PhosphorFill',
    fontPackage: 'phosphor_flutter',
  );

  /// Open book (credits / attribution).
  static const IconData bookOpen = IconData(
    0xe0e6,
    fontFamily: 'PhosphorFill',
    fontPackage: 'phosphor_flutter',
  );

  /// Right caret (row affordance).
  static const IconData caretRight = IconData(
    0xe13a,
    fontFamily: 'PhosphorFill',
    fontPackage: 'phosphor_flutter',
  );

  /// Left caret (top-left back affordance on pushed routes).
  static const IconData caretLeft = IconData(
    0xe138,
    fontFamily: 'PhosphorFill',
    fontPackage: 'phosphor_flutter',
  );

  /// Sign-out door (mid-round race quit).
  static const IconData signOut = IconData(
    0xe42a,
    fontFamily: 'PhosphorFill',
    fontPackage: 'phosphor_flutter',
  );

  /// Crown (crown ceremony, guide § 6 podium). Codepoint verified
  /// against phosphor_flutter 2.1.0 `PhosphorIconsFill.crown`
  /// (phosphor_icons_fill.dart line 1345) per ux-checklist § 6.
  static const IconData crown = IconData(
    0xe614,
    fontFamily: 'PhosphorFill',
    fontPackage: 'phosphor_flutter',
  );

  /// Speaker with waves (sound on).
  static const IconData speakerHigh = IconData(
    0xe44a,
    fontFamily: 'PhosphorFill',
    fontPackage: 'phosphor_flutter',
  );

  /// Tray download arrow (self-update row, GDD § 8.1). Codepoint
  /// verified against phosphor_flutter 2.1.0
  /// `PhosphorIconsFill.downloadSimple`
  /// (phosphor_icons_fill.dart line 1546).
  static const IconData downloadSimple = IconData(
    0xe20c,
    fontFamily: 'PhosphorFill',
    fontPackage: 'phosphor_flutter',
  );
}
