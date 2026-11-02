# SilentPing

An internet-connected foreground ping prototype for Android and web. Uses the existing `silentping-app` Firebase project with email/password authentication and Cloud Firestore. Native vibration works on Samsung; the iPhone browser shows a visual pulse.

## Connect two phones

1. Open the installed Samsung app and https://silentping-app.web.app on the iPhone.
2. Choose **New here? Create account** on each device. Use a different email/account on each phone.
3. On one phone, tap **Create invitation** and privately share its code with the other person.
4. On the other phone, paste the code and tap **Request connection**.
5. On the inviting phone, tap **Approve connection** after confirming you expected that person.
6. Keep both apps open. Tap one of the three signals to send it over the internet. Incoming signals vibrate Android and highlight the receiving connection. Browser reception is visual only.

The phones can use different networks. The computer does not need to keep running after deployment. **Disconnect** immediately revokes further cloud signal access. Invitations are single-use; cancel and recreate an invitation if the wrong person claims it. Password reset is available on the sign-in screen.

## Current limits

- Foreground reception only. This build does not register push tokens, deliver background notifications, or promise locked-phone vibration.
- A sent confirmation means Firestore accepted the write, not that the other phone received or felt it.
- Each connection stores only the latest signal per sender. The receiver ignores signals older than 30 seconds and those from before its current session. These records are not automatically deleted; no TTL retention policy has been configured.
- Server rules enforce a three-second cooldown per sender per connection. This is a private prototype; broader signup abuse controls, account deletion, verified identity and retention policies remain work before a public launch.
- Native iPhone installation still requires Mac/Xcode signing or TestFlight. This Windows setup provides the iPhone browser version.
- Do not use this prototype for safety or arrival confirmation.

## Run locally

Double-click `preview.cmd` for Chrome, or `preview-phone.cmd` for a Wi-Fi browser preview. Both now use the same cloud accounts and database as the hosted app. Browser vibration is not supported by this UI.

For Android, connect the Samsung with USB debugging enabled:

```powershell
flutter devices
flutter run -d DEVICE_ID
```

The old four-contact local demo remains in `CircleScreen` for UI/haptics regression tests; normal startup opens the cloud account screen.

## Firebase setup and deployment

Firebase apps are registered for Android (`com.example.silent_ping`) and web. Public SDK configuration is in `lib/firebase_options.dart`, `firebase-web.json` and `android/app/google-services.json`; these are identifiers, not service-account credentials. No admin credential belongs in the app.

Email/password authentication is enabled. Firestore rules restrict connection queries to members, require owner approval, bind signals to the authenticated sender, validate signal types and timestamps, enforce cooldowns, and deny signal access after disconnecting. A 128-bit invitation code grants permission to request a connection; share it privately.

```powershell
flutter analyze
flutter test
npm --prefix tools ci
firebase emulators:exec --only firestore --project demo-silentping "node --test tools/firestore.test.cjs"
flutter build web --release --no-web-resources-cdn
firebase deploy --only firestore:rules,hosting --project silentping-app
flutter build apk --debug --target-platform android-arm64
```

`tools/cloud-smoke.cjs` performs an optional live two-account round trip using temporary test identities, then removes its accounts and documents. It requires the Firebase CLI login for scoped cleanup. Run it only against this project's development environment. `tools/cloud-setup.cjs` inspects authentication settings and backs up existing rules; `--enable-email` enables password sign-in. These scripts never print login tokens or write passwords.

## Next delivery milestone

### Current priority: finish the free foreground version

Keep this project on Spark with no billing account linked. Do not enable Blaze or deploy Cloud Functions for this milestone. Normal builds leave Android push disabled. Authentication, Firestore and Hosting remain subject to their free usage limits; a quota error is a reason to wait and review usage, not to upgrade automatically.

Build the foreground version with `flutter build web --release --no-web-resources-cdn` and `flutter build apk --debug --target-platform android-arm64`. If publishing it, deploy only Hosting and rules using `firebase deploy --only firestore:rules,hosting --project silentping-app`; do not use an unrestricted deploy command.

Two-phone acceptance checklist (requires physical devices):

- Sign in with different accounts on Samsung and the iPhone browser, create an invitation, request connection and approve it.
- Keep both screens awake with SilentPing visible. Send all three signals in each direction, waiting at least three seconds between sends. Confirm Samsung vibration and the browser's visual pulse.
- Try sending rapidly and confirm the cooldown prevents repeated sends.
- Disconnect and confirm neither phone can send through that connection. Create a fresh invitation to reconnect.
- Sign out and back in; confirm old signals are not replayed. Check password reset with an account you control.
- Turn off internet and try an action; confirm the app explains the failure. A timed-out write can still arrive after reconnection, so do not interpret a timeout as cancellation.
- Background or lock a phone and confirm the interface makes no promise of delivery in that state.

Passing local checks does not complete this physical-device checklist.

### Deferred: background delivery

Android background delivery is prepared locally, but **not activated**. The Firebase project currently has billing disabled. Deploying Cloud Functions requires the Blaze plan; billing has not been enabled by this project work. The currently installed app and hosted page continue using foreground pings.

The prepared implementation includes an opt-in **Enable background pings** button, private Android device registration, token refresh and sign-out cleanup, and three quiet notification channels with distinct vibration patterns. The Firestore-triggered `deliverPing` function checks current consent and the latest signal, rejects signals older than 30 seconds, uses short-lived FCM notifications, and drops invalid device registrations. Foreground haptics continue through Firestore; Android handles background notification vibration. Notifications use generic text without a contact name or signal intent on the lock screen.

Duplicate function events are claimed transactionally before sending. This avoids repeat dispatch but can lose a push if the process crashes after claiming. Already accepted notifications cannot be recalled if disconnecting races with delivery. Device registrations are ignored after 30 days without a refresh. Deduplication claims include `expiresAt`; automatic Firestore TTL deletion still needs to be configured when deploying. These are best-effort notifications, not delivery receipts.

After the project owner enables Blaze and approves activation:

```powershell
cd functions
npm ci
npm test
cd ..
firebase deploy --only firestore:rules,functions:silentping --project silentping-app
flutter build apk --debug --target-platform android-arm64 --dart-define=ENABLE_ANDROID_PUSH=true
```

Install that build, sign in, enable background pings and allow Android notifications. Test a signal while the Samsung app is open, in the background, and with the phone locked; verify each pattern, sign-out, and disconnect. Notification channel settings, Do Not Disturb, battery restrictions, force-stop, and network conditions can silence or delay delivery. No live background-device test has been completed yet. Default builds omit the opt-in button until explicitly compiled with the deployment flag.

The functions test suite uses a fake FCM transport to verify routing, consent, expiry, duplicate dispatch and invalid-token cleanup without sending real notifications. Firestore emulator tests cover private token ownership in addition to pairing and cooldowns.

Native iPhone vibration remains a separate signed iOS build and physical-device testing task. See [Firebase function deployment requirements](https://firebase.google.com/docs/functions/get-started), [Apple background notifications](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app) and [FCM message priority](https://firebase.google.com/docs/cloud-messaging/android-message-priority).
