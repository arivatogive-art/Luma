// Pfad: lib/presentation/widgets/profile_block_state.dart

import 'package:flutter/foundation.dart';

@immutable
class ProfileBlockState {
  const ProfileBlockState({
    this.blockedByMe = false,
    this.blockedByOtherUser = false,
  });

  final bool blockedByMe;
  final bool blockedByOtherUser;

  bool get blockedBetweenUsers => blockedByMe || blockedByOtherUser;
}
