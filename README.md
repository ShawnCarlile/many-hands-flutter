# Many Hands (Flutter)

A Flutter mobile version (Android and iOS) of the **Many Hands** volunteer coordination app from class
([jmiel-tech/many-hands](https://github.com/jmiel-tech/many-hands), a React web app).

It has the same features and uses the **same Firestore data model and security rules**, so it can share one Firebase project with
the web version:

- Email/password sign up, log in, password reset, removed-member screen
- Home: your tasks, tasks that need someone, active issues
- Issues: search, Active/Resolved/All filter, health ring, task board (Unclaimed / To do / Doing / Done), issue discussion
- Tasks: take a task, update status, give it back, reassign (issue owner), comments, member workload indicator
- Calendar of due dates
- Members directory with search; profiles with Message, Call and Email
- Chat: public rooms plus private one-to-one messages
- Me: profile, edit profile, dark mode
- Admin: remove members and let them back in, edit or delete any issue

The AI assistant from the web app is left out on purpose (it ran on the original author's server).

## Project layout

| Path | What's in it |
| --- | --- |
| `lib/main.dart` | Starts Firebase and the app |
| `lib/router.dart` | Every screen's route. Five tabs at the bottom; the rest open on top |
| `lib/models.dart` | Typed Firestore documents (members, issues, tasks, comments, chats, bans) |
| `lib/services/` | `auth_service.dart` (sign-in, admin, bans), `data_service.dart` (live lists), `api.dart` (every read and write) |
| `lib/logic/` | Pure Dart ports of the web app's `src/lib` (dates, health, filters, phone, forms, errors) |
| `lib/screens/` | One file per screen or screen group |
| `lib/widgets/` | Shared widgets: badges, cards, comment threads, the tab shell |
| `firestore.rules` | Copied unchanged from the web app |
| `test/logic_test.dart` | Dart versions of the web app's unit tests |

## Set it up with your own Firebase

Do Part 2 of the class PDF first (create the project, turn on Email/Password sign-in, create Firestore, publish `firestore.rules`).
Then connect this app:

1. Install the Firebase and FlutterFire command line tools (once per computer):

   ```bash
   npm install -g firebase-tools
   ```

   ```bash
   dart pub global activate flutterfire_cli
   ```

2. Log in to Firebase:

   ```bash
   firebase login
   ```

3. In this folder, register the Android and iOS apps and write `lib/firebase_options.dart`:

   ```bash
   flutterfire configure --project=YOUR_PROJECT_ID --platforms=android,ios
   ```

4. Change `communityName` in `lib/config.dart` to your group's name.

5. Run it on an emulator or a plugged-in phone:

   ```bash
   flutter run
   ```

Sign up in the app, then check **Firestore Database > Data** for a `members` document. To make yourself an admin, follow Part 6 of the PDF
(add your UID to an `admins` collection).

The values in `firebase_options.dart` are public by design; `firestore.rules` protects the data. Never commit a service-account key.

## Try it without a Firebase project (local emulators)

Needs Java 21 or newer. Start the emulators in one terminal:

```bash
firebase emulators:start --only auth,firestore --project demo-many-hands
```

Run the app against them in another:

```bash
flutter run --dart-define=USE_EMULATOR=true
```

The emulator UI at <http://localhost:4000> shows the data. The Android emulator reaches your computer at `10.0.2.2`; the app handles that.
If ports 9099/8080 are already in use, start the emulators on other ports and pass them in, for example
`flutter run --dart-define=USE_EMULATOR=true --dart-define=AUTH_PORT=9199 --dart-define=FIRESTORE_PORT=8180`.

## iOS

Building for iOS needs Xcode and CocoaPods on a Mac. Firebase needs iOS 15 or newer: after the first `flutter build ios`, make sure
`ios/Podfile` has `platform :ios, '15.0'`.

## Tests

```bash
flutter test
```

```bash
flutter analyze
```
