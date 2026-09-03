// Pfad: lib/presentation/screens/update_gate.dart

import 'package:flutter/material.dart';

import '../../application/update_controller.dart';
import '../../application/update_state.dart';

class UpdateGate extends StatefulWidget {
  const UpdateGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  late final UpdateController _controller;

  @override
  void initState() {
    super.initState();
    _controller = UpdateController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUpdateCheck();
    });
  }

  Future<void> _initializeUpdateCheck() async {
    try {
      await _controller.initialize();
    } catch (_) {
      // Eine fehlgeschlagene optionale Update-Prüfung darf Luma nicht
      // vom Start abhalten. Ein echter Hard-Update-Zustand wird unten
      // weiterhin blockierend dargestellt.
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final state = _controller.state;

        if (state.status == LumaUpdateStatus.hardUpdateRequired) {
          return _RequiredUpdateScreen(
            state: state,
            onUpdateNow: _controller.updateNow,
          );
        }

        return child!;
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _RequiredUpdateScreen extends StatelessWidget {
  const _RequiredUpdateScreen({
    required this.state,
    required this.onUpdateNow,
  });

  final UpdateState state;
  final Future<void> Function() onUpdateNow;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.system_update_rounded,
                    size: 58,
                    color: Color(0xFFE58A2B),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    state.title.trim().isEmpty
                        ? 'Update erforderlich'
                        : state.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF102033),
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    state.message.trim().isEmpty
                        ? 'Aktualisiere Luma, um die App weiter verwenden zu können.'
                        : state.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF756D65),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        onUpdateNow();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE58A2B),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Luma aktualisieren'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
