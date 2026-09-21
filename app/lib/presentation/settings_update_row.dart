import 'dart:async' show unawaited;

import 'package:app/app_config.dart';
import 'package:app/design/tokens.dart';
import 'package:app/design/ttr_icons.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:app/design/widgets/ttr_settings_row.dart';
import 'package:app/infra/apk_store.dart';
import 'package:app/update/update_service.dart';
import 'package:app/update/version_compare.dart';
import 'package:flutter/material.dart';

/// Drives an APK download to a path (production: cache file via
/// `infra/apk_store.dart`; tests inject fakes).
typedef ApkDownloadDriver = Future<String> Function(
  Uri url, {
  void Function(double fraction)? onProgress,
});

/// Phases of the self-update row (docs/03 § 9 update-row states).
enum _UpdatePhase { checking, upToDate, available, downloading, error }

/// `UPDATE` group row (GDD § 8.1, guide § 6 Settings FORM): the
/// self-update state machine — checking (inline spinner) / up to
/// date (success tint) / available (`NEW VERSION` + action) /
/// downloading (linear progress) / error (retry action) — over the
/// injected [UpdateService]. Entry auto-queries once (ux-checklist
/// self-update row: never blocks the screen — the check runs
/// async and every failure degrades to a retry row).
class SettingsUpdateRow extends StatefulWidget {
  /// Creates the row.
  const SettingsUpdateRow({
    required this.service,
    this.downloadDriver,
    super.key,
  });

  /// Key of the whole update row (tests, Patrol).
  static const Key rowKey = Key('settings_update_row');

  /// Key of the download progress bar (tests).
  static const Key progressBarKey = Key('settings_update_progress');

  /// Update backend.
  final UpdateService service;

  /// APK download-to-path seam; `null` uses the cache-file writer.
  final ApkDownloadDriver? downloadDriver;

  @override
  State<SettingsUpdateRow> createState() => _SettingsUpdateRowState();
}

class _SettingsUpdateRowState extends State<SettingsUpdateRow> {
  /// Inline checking spinner edge (guide § 6 row state, compact
  /// trailing control — component geometry, not flow spacing).
  static const double _spinnerEdge = 16;
  static const double _spinnerStroke = 2;

  _UpdatePhase _phase = _UpdatePhase.checking;
  ReleaseInfo? _release;
  double _progress = 0;
  String _errorLine = '';

  @override
  void initState() {
    super.initState();
    // Settings-entry auto-query (GDD § 8.1): fire-and-forget by
    // design — the row starts in `checking` and the outcome
    // replaces it; errors are rendered, never swallowed.
    unawaited(_check());
  }

  Future<void> _check() async {
    setState(() => _phase = _UpdatePhase.checking);
    try {
      final release = await widget.service.checkLatest();
      if (!mounted) {
        return;
      }
      final order = VersionCompare.compare(
        current: appVersion,
        latestTag: release.tag,
      );
      setState(() {
        _release = release;
        _phase = order == VersionOrder.updateAvailable
            ? _UpdatePhase.available
            : _UpdatePhase.upToDate;
      });
    } on UpdateException catch (error) {
      _failCheck(error.reason);
    } on FormatException {
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = _UpdatePhase.error;
        _errorLine = 'Latest release tag could not be read.';
      });
    }
  }

  void _failCheck(UpdateFailureReason reason) {
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = _UpdatePhase.error;
      _errorLine = reason == UpdateFailureReason.offline ||
              reason == UpdateFailureReason.timeout
          ? 'Update check failed — check your connection.'
          : 'Update check failed.';
    });
  }

  Future<void> _download() async {
    final release = _release;
    if (release == null) {
      return;
    }
    setState(() {
      _phase = _UpdatePhase.downloading;
      _progress = 0;
    });
    final driver = widget.downloadDriver ?? _cacheFileDriver;
    try {
      final path = await driver(
        release.apkUrl,
        onProgress: (fraction) {
          if (mounted) {
            setState(() => _progress = fraction);
          }
        },
      );
      await widget.service.install(path);
      if (mounted) {
        // The system dialog may still be cancelled — the action
        // stays available (never a dead end).
        setState(() => _phase = _UpdatePhase.available);
      }
    } on UpdateException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = _UpdatePhase.error;
        _errorLine = error.reason == UpdateFailureReason.installFailed
            ? 'Install was blocked — try again.'
            : 'Download failed — check your connection.';
      });
    }
  }

  Future<String> _cacheFileDriver(
    Uri url, {
    void Function(double fraction)? onProgress,
  }) => downloadApkToFile(widget.service, url, onProgress: onProgress);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TtrSettingsRow(
          leading: TtrIcons.downloadSimple,
          title: 'Version v$appVersion',
          subtitle: _subtitle,
          trailing: _trailing,
        ),
        if (_phase == _UpdatePhase.available) ...[
          const SizedBox(height: SpacingScale.sm),
          TtrButton(label: 'DOWNLOAD UPDATE', onPressed: _download),
        ],
        if (_phase == _UpdatePhase.downloading) ...[
          const SizedBox(height: SpacingScale.sm),
          LinearProgressIndicator(
            key: SettingsUpdateRow.progressBarKey,
            value: _progress,
            minHeight: SpacingScale.sm,
            color: ColorPalette.primary,
            backgroundColor: ColorPalette.neutral200,
            borderRadius: BorderRadius.circular(RadiusScale.pill),
          ),
        ],
        if (_phase == _UpdatePhase.error) ...[
          const SizedBox(height: SpacingScale.sm),
          TtrButton(label: 'CHECK FOR UPDATES', onPressed: _check),
        ],
      ],
    );
  }

  String get _subtitle {
    final release = _release;
    return switch (_phase) {
      _UpdatePhase.checking => 'Checking for updates…',
      _UpdatePhase.upToDate => 'You are on the latest version',
      _UpdatePhase.available => 'NEW VERSION ${release?.tag} — '
          '${release?.notes}',
      _UpdatePhase.downloading => 'Downloading ${release?.tag}…',
      _UpdatePhase.error => _errorLine,
    };
  }

  Widget? get _trailing {
    return switch (_phase) {
      _UpdatePhase.checking => const SizedBox(
        width: _spinnerEdge,
        height: _spinnerEdge,
        child: CircularProgressIndicator(
          strokeWidth: _spinnerStroke,
          color: ColorPalette.primary,
        ),
      ),
      _UpdatePhase.upToDate => Text(
        'UP TO DATE',
        style: TypeScale.bodyLabel.copyWith(color: ColorPalette.success),
      ),
      _ => null,
    };
  }
}
