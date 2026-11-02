import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'haptics.dart';
import 'push_registration.dart';

String cloudError(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'email-already-in-use' =>
        'That email already has an account. Try signing in.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' =>
        'Choose a stronger password with at least 8 characters.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Check your email and password.',
      'network-request-failed' ||
      'unavailable' => 'Connection lost. Check your internet and retry.',
      'permission-denied' =>
        'This connection is unavailable, or you sent too quickly. Try again shortly.',
      'too-many-requests' => 'Too many attempts. Please wait and retry.',
      'resource-exhausted' =>
        'The service usage limit has been reached. Please try again later.',
      _ => 'Could not complete that action. Please retry.',
    };
  }
  if (error is TimeoutException) {
    return 'No server confirmation yet. Check your internet before retrying.';
  }
  if (error is StateError) return error.message;
  return 'Could not complete that action. Please retry.';
}

class CloudGate extends StatelessWidget {
  const CloudGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final user = snapshot.data;
      return user == null
          ? const AccountScreen()
          : ConnectedCircle(key: ValueKey(user.uid), user: user);
    },
  );
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool create = false;
  bool busy = false;
  String? message;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit({bool reset = false}) async {
    if (busy) return;
    if (email.text.trim().isEmpty || (!reset && password.text.length < 8)) {
      setState(
        () => message =
            'Enter your email and a password of at least 8 characters.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (reset) {
        await auth.sendPasswordResetEmail(email: email.text.trim());
        if (mounted) {
          setState(
            () => message =
                'If this email has an account, a reset link will arrive shortly.',
          );
        }
      } else if (create) {
        await auth.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } catch (error) {
      if (mounted) setState(() => message = cloudError(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(28),
          children: [
            const Icon(Icons.sensors, size: 44, color: Color(0xFFBCE5AA)),
            const SizedBox(height: 24),
            Text(
              'A quiet connection.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Use a different account on each phone. Connect privately with an invitation code.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Keep SilentPing open on both phones to receive pings. Android vibrates; the browser shows a visual pulse. Locked phones do not receive pings in this version.',
            ),
            const SizedBox(height: 28),
            TextField(
              controller: email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              enabled: !busy,
              obscureText: true,
              autofillHints: [
                create ? AutofillHints.newPassword : AutofillHints.password,
              ],
              decoration: const InputDecoration(labelText: 'Password'),
              onSubmitted: (_) => submit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : submit,
              child: Text(
                busy
                    ? 'Connecting…'
                    : create
                    ? 'Create account'
                    : 'Sign in',
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      create = !create;
                      message = null;
                    }),
              child: Text(
                create
                    ? 'Already have an account? Sign in'
                    : 'New here? Create account',
              ),
            ),
            TextButton(
              onPressed: busy ? null : () => submit(reset: true),
              child: const Text('Forgot password?'),
            ),
            if (message != null)
              Text(
                message!,
                textAlign: TextAlign.center,
                semanticsLabel: message,
              ),
          ],
        ),
      ),
    ),
  );
}

class ConnectedCircle extends StatefulWidget {
  const ConnectedCircle({super.key, required this.user});
  final User user;
  @override
  State<ConnectedCircle> createState() => _ConnectedCircleState();
}

class _ConnectedCircleState extends State<ConnectedCircle>
    with WidgetsBindingObserver {
  final invite = TextEditingController();
  final db = FirebaseFirestore.instance;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> rooms;
  final listeners =
      <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  final seen = <String, Timestamp>{};
  late final DateTime listeningSince;
  bool busy = false;
  String message =
      'Create an invitation or enter the code from the other phone.';
  String? activeRoom;
  final sending = <String>{};
  Timer? highlight;
  late final PushRegistration push;
  bool pushEnabled = false;
  bool foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    push = PushRegistration(
      widget.user.uid,
      onError: () {
        if (mounted) {
          setState(
            () => message =
                'Could not refresh background pings. Disable and enable them to retry.',
          );
        }
      },
    );
    if (androidPushAvailable) {
      busy = true;
      unawaited(_restorePush());
    }
    listeningSince = DateTime.now();
    rooms = db
        .collection('circles')
        .where('memberIds', arrayContains: widget.user.uid)
        .snapshots();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    push.dispose();
    invite.dispose();
    highlight?.cancel();
    for (final subscription in listeners.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
  }

  Future<void> _restorePush() async {
    try {
      final enabled = await push.restore();
      if (mounted) setState(() => pushEnabled = enabled);
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Could not restore background pings. Try enabling them again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> togglePush() => action(() async {
    if (pushEnabled) {
      await push.disable();
      if (mounted) {
        setState(() {
          pushEnabled = false;
          message = 'Background pings disabled on this phone.';
        });
      }
    } else {
      final enabled = await push.enable();
      if (mounted) {
        setState(() {
          pushEnabled = enabled;
          message = enabled
              ? 'Background pings enabled. Phone settings can still silence or delay them.'
              : 'Notifications are disabled. Allow them in Android settings to receive background pings.';
        });
      }
    }
  });

  Future<void> signOut() => action(() async {
    await push.disable();
    await FirebaseAuth.instance.signOut();
  });

  Future<void> action(Future<void> Function() task) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await task();
    } catch (error) {
      if (mounted) setState(() => message = cloudError(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> createInvite() => action(() async {
    final random = Random.secure();
    final code = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await db
        .collection('circles')
        .doc(code)
        .set({
          'ownerUid': widget.user.uid,
          'guestUid': '',
          'memberIds': [widget.user.uid],
          'status': 'waiting',
          'createdAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 15));
    if (mounted) {
      setState(
        () => message =
            'Share your invitation code privately. Approve the request when your friend joins.',
      );
    }
  });

  Future<void> join() => action(() async {
    final code = invite.text.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(code)) {
      throw StateError('Paste the full invitation code.');
    }
    final ref = db.collection('circles').doc(code);
    await db
        .runTransaction((transaction) async {
          final snapshot = await transaction.get(ref);
          if (!snapshot.exists) {
            throw StateError('Invitation not found. Check the code.');
          }
          final data = snapshot.data()!;
          if (data['ownerUid'] == widget.user.uid) {
            throw StateError('Use a different account on the other phone.');
          }
          if (data['status'] != 'waiting') {
            throw StateError(
              'This invitation has already been used or closed.',
            );
          }
          transaction.update(ref, {
            'guestUid': widget.user.uid,
            'memberIds': [data['ownerUid'], widget.user.uid],
            'status': 'pending',
          });
        })
        .timeout(const Duration(seconds: 15));
    if (mounted) {
      invite.clear();
      setState(
        () => message = 'Request sent. Ask the other person to approve it.',
      );
    }
  });

  void syncListeners(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final connected = docs
        .where((doc) => doc.data()['status'] == 'connected')
        .map((doc) => doc.id)
        .toSet();
    for (final id in listeners.keys.toList()) {
      if (!connected.contains(id)) {
        listeners.remove(id)?.cancel();
      }
    }
    for (final id in connected) {
      if (listeners.containsKey(id)) continue;
      listeners[id] = db
          .collection('circles')
          .doc(id)
          .collection('signals')
          .snapshots()
          .listen(
            (snapshot) async {
              if (snapshot.metadata.isFromCache) return;
              for (final change in snapshot.docChanges) {
                if (change.type == DocumentChangeType.removed ||
                    change.doc.id == widget.user.uid) {
                  continue;
                }
                final data = change.doc.data()!;
                final sentAt = data['sentAt'];
                if (sentAt is! Timestamp) continue;
                final key = '$id/${change.doc.id}';
                if (seen[key] != null && sentAt.compareTo(seen[key]!) <= 0) {
                  continue;
                }
                seen[key] = sentAt;
                final time = sentAt.toDate();
                if (time.isBefore(listeningSince) ||
                    DateTime.now().difference(time).inSeconds > 30) {
                  continue;
                }
                final signal = Signal.values
                    .where((s) => s.name == data['kind'])
                    .firstOrNull;
                if (signal == null || !mounted) continue;
                setState(() {
                  activeRoom = id;
                  message = 'Received: ${signal.label}';
                });
                highlight?.cancel();
                highlight = Timer(const Duration(seconds: 2), () {
                  if (mounted) setState(() => activeRoom = null);
                });
                try {
                  if (foreground) await previewSignal(signal);
                } catch (_) {
                  if (mounted) {
                    setState(
                      () =>
                          message = 'Ping received. Vibration is unavailable.',
                    );
                  }
                }
              }
            },
            onError: (Object error) {
              if (mounted) setState(() => message = cloudError(error));
            },
          );
    }
  }

  Future<void> send(String roomId, Signal signal) async {
    if (sending.contains(roomId)) return;
    setState(() => sending.add(roomId));
    try {
      await db
          .collection('circles')
          .doc(roomId)
          .collection('signals')
          .doc(widget.user.uid)
          .set({'kind': signal.name, 'sentAt': FieldValue.serverTimestamp()})
          .timeout(const Duration(seconds: 12));
      if (mounted) {
        setState(
          () => message =
              'Sent: ${signal.label}. Your friend must have SilentPing open.',
        );
      }
    } on TimeoutException {
      if (mounted) {
        setState(
          () => message =
              'No server confirmation yet. This ping may arrive if the connection returns.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => message = cloudError(error));
    } finally {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (mounted) setState(() => sending.remove(roomId));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('silentping'),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: busy ? null : signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Your circle',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(widget.user.email ?? 'Signed in'),
            const SizedBox(height: 12),
            Text(
              kIsWeb
                  ? 'Keep this page open to receive pings. Browser pings light up the screen.'
                  : pushEnabled
                  ? 'Background pings use quiet Android notifications. Device settings may silence or delay them.'
                  : 'Keep this app open to receive vibrations.',
            ),
            if (androidPushAvailable)
              TextButton.icon(
                onPressed: busy ? null : togglePush,
                icon: Icon(
                  pushEnabled
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none,
                ),
                label: Text(
                  pushEnabled
                      ? 'Disable background pings'
                      : 'Enable background pings',
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: busy ? null : createInvite,
              icon: const Icon(Icons.add),
              label: const Text('Create invitation'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: invite,
              enabled: !busy,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Invitation code from your friend',
              ),
            ),
            TextButton(
              onPressed: busy ? null : join,
              child: const Text('Request connection'),
            ),
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: const TextStyle(color: Color(0xFFBCE5AA)),
              ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: rooms,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text(cloudError(snapshot.error!));
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) syncListeners(docs);
                });
                final visible = docs
                    .where((d) => d.data()['status'] != 'closed')
                    .toList();
                if (visible.isEmpty) {
                  return const Text(
                    'No connections yet. Start with an invitation.',
                  );
                }
                return Column(
                  children: visible.map((doc) {
                    final data = doc.data();
                    final owner = data['ownerUid'] == widget.user.uid;
                    final status = data['status'];
                    return Card(
                      color: activeRoom == doc.id
                          ? const Color(0xFF30452D)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status == 'connected'
                                  ? 'Connected friend'
                                  : status == 'pending'
                                  ? 'Connection request'
                                  : 'Your invitation',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            if (status == 'waiting') ...[
                              SelectableText(doc.id),
                              TextButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: doc.id),
                                  );
                                  if (mounted) {
                                    setState(
                                      () => message =
                                          'Invitation code copied. Share it privately.',
                                    );
                                  }
                                },
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy code'),
                              ),
                            ],
                            if (status == 'pending')
                              Text(
                                owner
                                    ? 'Only approve if you expected your friend to join using this code.'
                                    : 'Waiting for your friend to approve.',
                              ),
                            if (status == 'pending' && owner)
                              FilledButton(
                                onPressed: busy
                                    ? null
                                    : () => action(
                                        () => doc.reference.update({
                                          'status': 'connected',
                                        }),
                                      ),
                                child: const Text('Approve connection'),
                              ),
                            if (status == 'connected')
                              Wrap(
                                spacing: 8,
                                children: Signal.values
                                    .map(
                                      (signal) => ActionChip(
                                        avatar: Icon(signal.icon, size: 18),
                                        label: Text(signal.label),
                                        onPressed: sending.contains(doc.id)
                                            ? null
                                            : () => send(doc.id, signal),
                                      ),
                                    )
                                    .toList(),
                              ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => action(
                                      () => doc.reference.update({
                                        'status': 'closed',
                                      }),
                                    ),
                              child: Text(
                                status == 'connected'
                                    ? 'Disconnect'
                                    : 'Cancel invitation',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
