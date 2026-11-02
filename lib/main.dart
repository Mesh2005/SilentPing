import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'haptics.dart';
import 'cloud_screen.dart';
import 'app_style.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: AppStartup()),
  );
}

class AppStartup extends StatefulWidget {
  const AppStartup({super.key});
  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  late Future<FirebaseApp> initialization;
  @override
  void initState() {
    super.initState();
    initialization = initialize();
  }

  Future<FirebaseApp> initialize() => Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).timeout(const Duration(seconds: 20));
  @override
  Widget build(BuildContext context) => Theme(
    data: silentPingTheme(),
    child: FutureBuilder<FirebaseApp>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return LoadingScreen(
            error:
                'Could not open SilentPing. Check your internet and try again.',
            onRetry: () => setState(() => initialization = initialize()),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingScreen();
        }
        return const SilentPingApp(cloud: true);
      },
    ),
  );
}

class SilentPingApp extends StatelessWidget {
  const SilentPingApp({super.key, this.cloud = false});
  final bool cloud;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SilentPing',
    debugShowCheckedModeBanner: false,
    theme: silentPingTheme(),
    home: cloud ? const CloudGate() : const CircleScreen(),
  );
}

class CircleScreen extends StatefulWidget {
  const CircleScreen({super.key});
  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen> {
  static const contacts = ['Alex', 'Sam', 'Jamie', 'Morgan'];
  String? active;
  String status = 'Tap someone to preview a ping';
  bool busy = false;

  Future<void> ping(String name, Signal signal) async {
    if (busy) return;
    setState(() {
      busy = true;
      active = name;
      status = '${signal.label} · local preview';
    });
    try {
      await previewSignal(signal);
      await Future<void>.delayed(const Duration(milliseconds: 650));
    } catch (_) {
      if (mounted) setState(() => status = 'Haptic preview unavailable');
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          active = null;
        });
      }
    }
  }

  Future<void> chooseSignal(String name) async {
    if (busy) return;
    final signal = await showModalBottomSheet<Signal>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF1C2820),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'A little signal for $name',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              for (final signal in Signal.values)
                ListTile(
                  leading: Icon(signal.icon),
                  title: Text(signal.label),
                  subtitle: Text(signal.description),
                  onTap: () => Navigator.pop(context, signal),
                ),
            ],
          ),
        ),
      ),
    );
    if (signal != null && mounted) await ping(name, signal);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            children: [
              Row(
                children: [
                  const Icon(Icons.sensors, color: Color(0xFFBCE5AA), size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'silentping',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  const Chip(label: Text('LOCAL DEMO')),
                ],
              ),
              const SizedBox(height: 52),
              Text(
                'Less to say.\nMore to feel.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'A small signal. A quiet connection.',
                style: TextStyle(color: Color(0xFFA5B5A8), fontSize: 16),
              ),
              const SizedBox(height: 44),
              const Text(
                'YOUR CIRCLE',
                style: TextStyle(
                  letterSpacing: 2,
                  fontSize: 11,
                  color: Color(0xFFA5B5A8),
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < contacts.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    button: true,
                    label:
                        '${contacts[i]}. Tap for a local ping preview. Long press to choose a signal.',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: active == contacts[i]
                            ? const Color(0xFF30452D)
                            : const Color(0xFF1A251E),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: active == contacts[i]
                              ? const Color(0xFFBCE5AA)
                              : const Color(0xFF2A382D),
                        ),
                        boxShadow: active == contacts[i]
                            ? [
                                const BoxShadow(
                                  color: Color(0x338ECD78),
                                  blurRadius: 24,
                                  spreadRadius: 5,
                                ),
                              ]
                            : [],
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          enabled: !busy,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF354638),
                            foregroundColor: const Color(0xFFD3E9CB),
                            child: Text(contacts[i][0]),
                          ),
                          title: Text(
                            contacts[i],
                            style: const TextStyle(fontSize: 18),
                          ),
                          subtitle: const Text(
                            'Demo contact',
                            style: TextStyle(
                              color: Color(0xFFA5B5A8),
                              fontSize: 12,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Choose signal for ${contacts[i]}',
                            onPressed: busy
                                ? null
                                : () => chooseSignal(contacts[i]),
                            icon: const Icon(
                              Icons.sensors,
                              color: Color(0xFFBCE5AA),
                            ),
                          ),
                          onTap: () => ping(contacts[i], Signal.ambient),
                          onLongPress: () => chooseSignal(contacts[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: Text(
                  status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFBCE5AA)),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                kIsWeb
                    ? 'Click a contact to preview. Click its signal icon for options.\nBrowser preview uses visual feedback only.'
                    : 'Hold a contact to choose a signal.\nPreviews vibrate this device only.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFA5B5A8),
                  height: 1.6,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
