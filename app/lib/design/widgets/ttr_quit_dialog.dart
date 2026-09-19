import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:flutter/material.dart';

/// Confirm dialog for quitting a race mid-round (GDD § 7.11 solo
/// abandon): tokened AlertDialog — TypeScale + ColorPalette +
/// RadiusScale only. Completes `true` on QUIT, `false`/`null`
/// (dismiss) otherwise.
class TtrQuitDialog extends StatelessWidget {
  /// Creates the dialog.
  const TtrQuitDialog({super.key});

  /// Key of the dialog surface (tests).
  static const Key dialogKey = Key('ttr_quit_dialog');

  /// Key of the QUIT confirm button (tests).
  static const Key confirmButtonKey = Key('ttr_quit_confirm');

  /// Key of the KEEP RUNNING dismiss button (tests).
  static const Key keepRunningButtonKey = Key('ttr_quit_keep_running');

  /// Shows the modal confirm over [context]; the future completes
  /// with whether the player confirmed the quit.
  static Future<bool> show(BuildContext context) async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (_) => const TtrQuitDialog(),
    );
    return quit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: dialogKey,
      backgroundColor: ColorPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RadiusScale.card),
      ),
      title: const Text('Quit the race?', style: TypeScale.title),
      content: Text(
        'Your race will not be recorded.',
        style: TypeScale.body.copyWith(color: ColorPalette.neutral500),
      ),
      actions: <Widget>[
        TtrButton(
          key: confirmButtonKey,
          label: 'QUIT',
          variant: TtrButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        TtrButton(
          key: keepRunningButtonKey,
          label: 'KEEP RUNNING',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
