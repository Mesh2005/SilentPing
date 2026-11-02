import 'package:flutter/material.dart';
import 'haptics.dart';

const ink = Color(0xFF101C19);
const muted = Color(0xFF9CAFA5);
const lime = Color(0xFFD5F5A4);

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, this.error, this.onRetry});
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PingMark(size: 150),
              const SizedBox(height: 28),
              const Text(
                'silentping',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                error ?? 'Making space for your people.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, height: 1.5),
              ),
              const SizedBox(height: 32),
              if (error == null) ...[
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Opening your circle...',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ] else
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CircleTile extends StatelessWidget {
  const CircleTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.received = false,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool received;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: received ? const Color(0xFF344A2D) : const Color(0xFF1B2A24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: received ? lime : const Color(0xFF34443B)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              const PingMark(size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      received ? 'New ping received' : subtitle,
                      style: const TextStyle(color: muted, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: lime),
            ],
          ),
        ),
      ),
    ),
  );
}

ThemeData silentPingTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: ink,
  fontFamily: 'SilentPing',
  colorScheme: ColorScheme.fromSeed(
    seedColor: lime,
    brightness: Brightness.dark,
    primary: lime,
    surface: const Color(0xFF1B2A24),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: ink,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF15231E),
    contentPadding: const EdgeInsets.all(18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFF3B4B42)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFF3B4B42)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 56),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
);

class PingMark extends StatelessWidget {
  const PingMark({super.key, this.size = 112});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: lime.withValues(alpha: .16)),
      ),
      padding: EdgeInsets.all(size * .13),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: lime.withValues(alpha: .32)),
        ),
        padding: EdgeInsets.all(size * .12),
        child: Container(
          decoration: const BoxDecoration(color: lime, shape: BoxShape.circle),
          child: Icon(Icons.sensors_rounded, color: ink, size: size * .3),
        ),
      ),
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: color ?? const Color(0xFF1B2A24),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xFF34443B)),
    ),
    child: child,
  );
}

class StatusNote extends StatelessWidget {
  const StatusNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
  });
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: lime),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: muted, height: 1.5)),
        ),
      ],
    ),
  );
}

/// A vertical layout keeps every signal readable on narrow phones and at large text sizes.
class SignalButtons extends StatelessWidget {
  const SignalButtons({super.key, required this.onSend, this.sending = false});
  final ValueChanged<Signal> onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final signal in Signal.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton(
            onPressed: sending ? null : () => onSend(signal),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              side: const BorderSide(color: Color(0xFF435447)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Icon(signal.icon, color: sending ? muted : lime, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(signal.label, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        signal.description,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  sending
                      ? Icons.hourglass_top_rounded
                      : Icons.arrow_outward_rounded,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      if (sending)
        const Text('Sending / cooling down...', style: TextStyle(color: muted)),
    ],
  );
}
