// § 11.2 case 6 — profile flow: avatar entry opens the profile
// screen; the nickname editor is present; back returns Home.
// (Nickname persistence + swatch edits are widget-test territory —
// this case only asserts the screen flow, per suite instructions.)
import 'package:app/design/widgets/ttr_back_button.dart';
import 'package:app/presentation/home_screen.dart';
import 'package:app/presentation/profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart' as helpers;

void main() {
  patrolTest(
    'profile_flow_opens_editor_and_back_returns_home',
    ($) async {
      // Arrange: on Home (own onboarding guard).
      await helpers.reachHome($);

      // Act: open profile via the avatar entry (keyed control).
      await $.tap(find.byKey(HomeScreen.profileButtonKey));

      // Assert 1: profile editor visible — the nickname field
      // (keyed; its visible label 'NICKNAME' is InputDecorator
      // internal text, so the key is the stable public anchor).
      await $.waitUntilVisible(
        find.byKey(ProfileScreen.nicknameFieldKey),
        timeout: const Duration(seconds: 10),
      );

      // Act 2: leave via the shared back affordance.
      await $.tap(find.byKey(TtrBackButton.buttonKey));

      // Assert 2: back on Home (§ 9 anchor).
      await $.waitUntilVisible(
        find.text('PLAY SOLO'),
        timeout: const Duration(seconds: 10),
      );
    },
  );
}
