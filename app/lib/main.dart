import 'package:app/design/theme.dart';
import 'package:app/shell_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Immersive fullscreen (design guide § 8): hide status and
  // navigation bars; content still respects SafeArea for display
  // cutouts. Portrait-only: the whole shell is designed vertical.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  runApp(const TongTongApp());
}

/// Root widget: hosts the immersive app shell.
class TongTongApp extends StatelessWidget {
  /// Creates the app root.
  const TongTongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TongTong Royal',
      theme: buildTtrTheme(),
      home: const ShellScaffold(),
    );
  }
}
