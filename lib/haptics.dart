import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum Signal {
  ambient('Thinking of you', 'A soft pulse', Icons.favorite_outline),
  arrival('Arrived safely', 'Two gentle pulses', Icons.home_outlined),
  attention('Need a moment', 'A firm pulse', Icons.waving_hand_outlined);

  const Signal(this.label, this.description, this.icon);
  final String label;
  final String description;
  final IconData icon;
}

// Foreground previews only. Remote delivery belongs behind a separate service.
Future<void> previewSignal(Signal signal) async {
  if (kIsWeb) return;
  if (defaultTargetPlatform == TargetPlatform.android) {
    await const MethodChannel(
      'silent_ping/haptics',
    ).invokeMethod<void>('preview', signal.name);
    return;
  }
  switch (signal) {
    case Signal.ambient:
      await HapticFeedback.lightImpact();
    case Signal.arrival:
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await HapticFeedback.mediumImpact();
    case Signal.attention:
      await HapticFeedback.heavyImpact();
  }
}
