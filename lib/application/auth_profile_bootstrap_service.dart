// Pfad: lib/application/auth_profile_bootstrap_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/user_profile_repository.dart';

// ignore_for_file: prefer_initializing_formals

class AuthProfileBootstrapService {
  const AuthProfileBootstrapService({
    FirebaseAuth? firebaseAuth,
    UserProfileRepository? userProfileRepository,
  })  : _firebaseAuth = firebaseAuth,
        _userProfileRepository = userProfileRepository;

  final FirebaseAuth? _firebaseAuth;
  final UserProfileRepository? _userProfileRepository;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;

  UserProfileRepository get _repository {
    return _userProfileRepository ?? UserProfileRepository();
  }

  Future<bool> ensureCurrentUserProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      debugPrint('AUTH PROFILE BOOTSTRAP: skipped, no current user.');
      return false;
    }

    final userId = user.uid.trim();

    if (userId.isEmpty) {
      debugPrint('AUTH PROFILE BOOTSTRAP: skipped, empty uid.');
      return false;
    }

    final displayName = user.displayName?.trim();
    final email = user.email?.trim();
    final phoneNumber = user.phoneNumber?.trim();
    final avatarUrl = user.photoURL?.trim();

    final fallbackDisplayName = displayName != null && displayName.isNotEmpty
        ? displayName
        : email != null && email.isNotEmpty
            ? email.split('@').first
            : 'Luma Nutzer';

    try {
      final profile = await _repository.createProfileIfMissing(
        userId: userId,
        displayName: fallbackDisplayName,
        email: email != null && email.isNotEmpty ? email : null,
        phoneNumber:
            phoneNumber != null && phoneNumber.isNotEmpty ? phoneNumber : null,
        avatarUrl: avatarUrl != null && avatarUrl.isNotEmpty ? avatarUrl : null,
      );

      await _repository.repairOwnSearchFields(
        userId: userId,
      );

      debugPrint('AUTH PROFILE BOOTSTRAP: ensured users/$userId');
      debugPrint('AUTH PROFILE BOOTSTRAP: profile=${profile.id}');

      return true;
    } catch (error, stackTrace) {
      debugPrint('AUTH PROFILE BOOTSTRAP FAILED: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}

