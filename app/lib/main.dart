import 'package:app/presentation/phase_router.dart';
import 'package:app/shell_controller.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const TongTongApp());
}

/// Root widget: wires [ShellController] into the phase router.
class TongTongApp extends StatelessWidget {
  /// Creates the app root.
  const TongTongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TongTong Royal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const ShellScaffold(),
    );
  }
}

/// Hosts the [PhaseRouter] with a stable app bar chrome.
class ShellScaffold extends StatefulWidget {
  /// Creates the shell scaffold.
  const ShellScaffold({super.key});

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold> {
  final ShellController _controller = ShellController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TongTong Royal')),
      body: PhaseRouter(controller: _controller),
    );
  }
}
