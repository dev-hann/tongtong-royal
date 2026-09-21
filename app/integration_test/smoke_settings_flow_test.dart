// § 11.2 case 7 — settings flow: gear opens settings, the sound
// toggle flips, credits list every ATTRIBUTION row, back ×2 lands
// on Home.
import 'package:app/design/widgets/ttr_back_button.dart';
import 'package:app/design/widgets/ttr_switch.dart';
import 'package:app/presentation/home_screen.dart';
import 'package:app/presentation/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart' as helpers;

void main() {
  patrolTest('settings_flow_toggle_flips_credits_list_back_home', ($) async {
    // Arrange: on Home (own onboarding guard).
    await helpers.reachHome($);

    // Act: open settings via the gear (keyed control).
    await $.tap(find.byKey(HomeScreen.settingsButtonKey));

    // Assert 1: settings visible — Sound row (§ 9-adjacent
    // visible label from the row title).
    await $.waitUntilVisible(
      find.text('Sound'),
      timeout: const Duration(seconds: 10),
    );

    // Assert 1b: self-update row exists (GDD § 8.1). Outcome depends
    // on live network + the device's current version — assert the
    // ROW, never a GitHub-derived state (docs/03 § 11.1 network-dependent-UI rule).
    await $.waitUntilVisible(
      find.text('UPDATE'),
      timeout: const Duration(seconds: 10),
    );
    await $.waitUntilVisible(
      find.byKey(SettingsScreen.updateRowKey),
      timeout: const Duration(seconds: 10),
    );

    // Act 2 + Assert 2: tap the toggle and read the flip off the
    // widget's public `value` (token visuals carry no text; the
    // initial state is persisted device data, so only the FLIP is
    // deterministic).
    final before = $.tester
        .widget<TtrSwitch>(find.byKey(SettingsScreen.soundToggleKey))
        .value;
    await $.tap(find.byKey(SettingsScreen.soundToggleKey));
    await $.pump(const Duration(milliseconds: 300));
    final after = $.tester
        .widget<TtrSwitch>(find.byKey(SettingsScreen.soundToggleKey))
        .value;
    expect(after, isNot(before), reason: 'sound toggle must flip on tap');

    // Act 3: open credits.
    await $.tap(find.byKey(SettingsScreen.creditsRowKey));

    // Assert 3: every ATTRIBUTION row is listed (credits_screen
    // mirrors ATTRIBUTION.md; keep in sync with it).
    await $.waitUntilVisible(
      find.text('Fredoka font'),
      timeout: const Duration(seconds: 10),
    );
    await $.waitUntilVisible(find.text('Nunito font'));
    await $.waitUntilVisible(find.text('Phosphor Icons (Fill)'));
    // Generated SFX placeholders row (exists check: the row may
    // sit below the fold on small viewports).
    await $('Sound effects').waitUntilExists();

    // Act 4: back to settings, then back to Home.
    await $.tap(find.byKey(TtrBackButton.buttonKey));
    await $.waitUntilVisible(
      find.text('Sound'),
      timeout: const Duration(seconds: 10),
    );
    await $.tap(find.byKey(TtrBackButton.buttonKey));

    // Assert 4: Home (§ 9 anchor).
    await $.waitUntilVisible(
      find.text('PLAY SOLO'),
      timeout: const Duration(seconds: 10),
    );
  });
}
