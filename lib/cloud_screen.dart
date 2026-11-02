import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'haptics.dart';
import 'app_style.dart';
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
        return const LoadingScreen();
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
  bool started = false;
  bool hidePassword = true;
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

  Widget welcome() => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: [
              const Text(
                'silentping',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 52),
              const Center(child: PingMark(size: 190)),
              const SizedBox(height: 36),
              const Text(
                'Your people.\nJust a pulse away.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 38,
                  height: 1.15,
                  letterSpacing: -1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'For the little moments that do not need a whole conversation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 16, height: 1.6),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => setState(() {
                  started = true;
                  create = true;
                }),
                child: const Text('Create account'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => setState(() {
                  started = true;
                  create = false;
                }),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 56),
                ),
                child: const Text('Sign in'),
              ),
              const SizedBox(height: 24),
              const StatusNote(
                text:
                    'Private invitations. Gentle signals. Keep the app open to receive pings.',
                icon: Icons.favorite_outline,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => !started
      ? welcome()
      : PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && !busy) {
              setState(() {
                started = false;
                message = null;
              });
            }
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Back',
                onPressed: busy
                    ? null
                    : () => setState(() {
                        started = false;
                        message = null;
                      }),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: Text(create ? 'Create account' : 'Sign in'),
            ),

            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.sizeOf(context).width < 360
                          ? 20
                          : 28,
                      vertical: 28,
                    ),
                    children: [
                      const Center(child: PingMark(size: 80)),
                      const SizedBox(height: 24),
                      Panel(
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                create ? 'Start your circle.' : 'Welcome back.',
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                create
                                    ? 'Create your account to connect.'
                                    : 'Sign in to your circle.',
                                style: const TextStyle(color: muted),
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                controller: email,
                                enabled: !busy,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: 'Email address',
                                  prefixIcon: Icon(
                                    Icons.alternate_email_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: password,
                                enabled: !busy,
                                obscureText: hidePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: [
                                  create
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password,
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  helperText: create
                                      ? 'At least 8 characters'
                                      : null,
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: hidePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () => setState(
                                      () => hidePassword = !hidePassword,
                                    ),
                                    icon: Icon(
                                      hidePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => submit(),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => submit(reset: true),
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton(
                                onPressed: busy ? null : submit,
                                child: busy
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        create ? 'Create account' : 'Sign in',
                                      ),
                              ),
                              const SizedBox(height: 8),
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
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              if (message != null) ...[
                                const SizedBox(height: 12),
                                StatusNote(text: message!),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const StatusNote(
                        text:
                            'Keep the app open on both phones. Android receives vibrations; browsers show a visual pulse. Locked-phone delivery is not available.',
                        icon: Icons.sensors_rounded,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Your own account. Your own small circle.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
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
  String? selectedRoom;
  bool addingCircle = false;
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
      setState(() {
        selectedRoom = code;
        addingCircle = false;
        message =
            'Share your invitation code privately. Approve the request when your friend joins.';
      });
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
      selectedRoom = code;
      addingCircle = false;
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

  Future<void> closeConnection(
    DocumentReference<Map<String, dynamic>> ref,
    bool connected,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          connected ? 'Disconnect this friend?' : 'Close this invitation?',
        ),
        content: Text(
          connected
              ? 'Pings will stop for both of you. You can reconnect with a new invitation.'
              : 'This code will no longer accept a connection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(connected ? 'Disconnect' : 'Close invitation'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await action(() => ref.update({'status': 'closed'}));
    }
  }

  Widget connectionCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final owner = data['ownerUid'] == widget.user.uid;
    final status = data['status'];
    final connected = status == 'connected';
    final received = activeRoom == doc.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: received
              ? [BoxShadow(color: lime.withValues(alpha: .18), blurRadius: 24)]
              : [],
        ),
        child: Panel(
          color: received ? const Color(0xFF344A2D) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: lime.withValues(alpha: .12),
                    foregroundColor: lime,
                    child: Icon(
                      connected
                          ? Icons.favorite_outline
                          : Icons.person_add_alt_1_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connected
                              ? 'Connected friend'
                              : status == 'pending'
                              ? 'Connection request'
                              : 'Your invitation',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          received
                              ? 'A little signal, just for you'
                              : connected
                              ? 'One small gesture away'
                              : status == 'pending'
                              ? 'Waiting for approval'
                              : 'Share your private code',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (status == 'waiting') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SelectableText(
                    doc.id,
                    style: const TextStyle(fontSize: 14, letterSpacing: 1.2),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      await Clipboard.setData(ClipboardData(text: doc.id));
                      if (mounted) {
                        setState(
                          () => message =
                              'Invitation code copied. Share it privately.',
                        );
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => message =
                              'Could not copy. Select the code to copy it manually.',
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy invitation code'),
                ),
              ],
              if (status == 'pending') ...[
                Text(
                  owner
                      ? 'Only approve if you expected your friend to join using this code.'
                      : 'Your friend needs to approve your request. Keep this app open.',
                  style: const TextStyle(color: muted, height: 1.5),
                ),
                const SizedBox(height: 12),
                if (owner)
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => action(
                            () => doc.reference.update({'status': 'connected'}),
                          ),
                    child: const Text('Approve connection'),
                  ),
              ],
              if (connected)
                SignalButtons(
                  sending: busy || sending.contains(doc.id),
                  onSend: (signal) => send(doc.id, signal),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () => closeConnection(doc.reference, connected),
                  child: Text(
                    connected ? 'Disconnect' : 'Cancel invitation',
                    style: const TextStyle(color: muted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: selectedRoom == null && !addingCircle,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        setState(() {
          selectedRoom = null;
          addingCircle = false;
        });
      }
    },
    child: Scaffold(
      floatingActionButton: addingCircle || selectedRoom != null
          ? null
          : FloatingActionButton.extended(
              onPressed: busy
                  ? null
                  : () => setState(() => addingCircle = true),
              backgroundColor: lime,
              foregroundColor: ink,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add circle'),
            ),
      appBar: AppBar(
        leading: addingCircle || selectedRoom != null
            ? IconButton(
                tooltip: 'All circles',
                onPressed: () => setState(() {
                  addingCircle = false;
                  selectedRoom = null;
                }),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: const Text(
          'silentping',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -1),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: busy ? null : signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width < 360 ? 16 : 24,
                vertical: 20,
              ),
              children: [
                Text(
                  addingCircle
                      ? 'Grow your circle.'
                      : selectedRoom != null
                      ? 'A moment for two.'
                      : 'Choose your circle.',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.user.email ?? 'Your private circle',
                  style: const TextStyle(color: muted),
                ),
                const SizedBox(height: 24),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.sensors_rounded, color: lime),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Small signals. Real connection.',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        kIsWeb
                            ? 'Keep this page open. Incoming pings appear as a visual pulse.'
                            : pushEnabled
                            ? 'Background pings are enabled. Phone settings can silence or delay notifications.'
                            : 'Keep the app open and your screen awake to receive gentle vibrations.',
                        style: const TextStyle(color: muted, height: 1.5),
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
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'YOUR PRIVATE CONNECTIONS',
                  style: TextStyle(
                    fontSize: 12,
                    color: muted,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                if (!addingCircle)
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: rooms,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: StatusNote(text: cloudError(snapshot.error!)),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(28),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final docs = snapshot.data!.docs;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) syncListeners(docs);
                      });
                      final visible = docs
                          .where((doc) => doc.data()['status'] != 'closed')
                          .toList();
                      if (visible.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Panel(
                            child: Column(
                              children: [
                                PingMark(size: 88),
                                SizedBox(height: 16),
                                Text(
                                  'Good things start with one person.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 20, height: 1.3),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Invite someone you care about. A private code connects just the two of you.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: muted, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final selected = visible
                          .where((doc) => doc.id == selectedRoom)
                          .firstOrNull;
                      if (selected != null) return connectionCard(selected);
                      return Column(
                        children: visible
                            .map(
                              (doc) => CircleTile(
                                title:
                                    'Circle ${doc.id.substring(0, 4).toUpperCase()}',
                                subtitle: doc.data()['status'] == 'connected'
                                    ? 'Connected / Tap to send a ping'
                                    : doc.data()['status'] == 'pending'
                                    ? 'Connection request / Review'
                                    : 'Invitation / Share your code',
                                received: activeRoom == doc.id,
                                onTap: () =>
                                    setState(() => selectedRoom = doc.id),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                const SizedBox(height: 8),
                if (addingCircle)
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Make a connection',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Use a different account on each phone.',
                          style: TextStyle(color: muted, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: busy ? null : createInvite,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create invitation'),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            'or join your friend',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ),
                        TextField(
                          controller: invite,
                          enabled: !busy,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => join(),
                          decoration: const InputDecoration(
                            labelText: 'Invitation code',
                            hintText: 'Paste your private code',
                            prefixIcon: Icon(Icons.link_rounded),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: busy ? null : join,
                          child: const Text('Request connection'),
                        ),
                        if (busy) const LinearProgressIndicator(),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                StatusNote(text: message),
                const SizedBox(height: 24),
                const Text(
                  'A ping is a gesture, not a delivery receipt.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
