// Pfad: lib/application/messenger_remote_mode.dart

enum MessengerRemoteMode {
  mockOnly,
  remoteWithMockFallback,
  remoteOnly,
}

extension MessengerRemoteModeX on MessengerRemoteMode {
  bool get usesRemote => this != MessengerRemoteMode.mockOnly;

  bool get allowsMockFallback =>
      this == MessengerRemoteMode.mockOnly ||
      this == MessengerRemoteMode.remoteWithMockFallback;

  bool get isRemoteOnly => this == MessengerRemoteMode.remoteOnly;
}
