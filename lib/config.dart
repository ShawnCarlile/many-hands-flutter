// Shown as a small label at the top of screens. Change it to your group's name.
const communityName = 'Your group name here';

// Run against the local Firebase emulators instead of a real project:
//   flutter run --dart-define=USE_EMULATOR=true
const useEmulator = bool.fromEnvironment('USE_EMULATOR');
// Change these with --dart-define=AUTH_PORT=... / FIRESTORE_PORT=... if 9099/8080 are taken.
const emulatorAuthPort = int.fromEnvironment('AUTH_PORT', defaultValue: 9099);
const emulatorFirestorePort = int.fromEnvironment('FIRESTORE_PORT', defaultValue: 8080);
