// Pfad: lib/application/account_deletion_service.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountDeletionService {
  AccountDeletionService({
    FirebaseAuth? firebaseAuth,
    FirebaseFunctions? firebaseFunctions,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _functions =
           firebaseFunctions ??
           FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Future<AccountDeletionResult> deleteCurrentAccount() async {
    final user = _auth.currentUser;
    final userId = user?.uid.trim() ?? '';

    if (user == null || userId.isEmpty) {
      throw const AccountDeletionException(
        code: 'no-current-user',
        message:
            'Deine Anmeldung ist nicht mehr aktiv. Bitte melde dich erneut an.',
      );
    }

    try {
      await user.getIdToken(true);

      final callable = _functions.httpsCallable(
        'deleteCurrentUserAccount',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
      );

      final response = await callable.call<Map<String, dynamic>>();

      final data = Map<String, dynamic>.from(response.data);

      if (data['success'] != true || data['accountDeleted'] != true) {
        throw const AccountDeletionException(
          code: 'deletion-not-confirmed',
          message:
              'Die Kontolöschung wurde vom Server nicht vollständig bestätigt.',
        );
      }

      return AccountDeletionResult(
        userId: userId,
        profileDeleted: data['profileDeleted'] == true,
        userContentDeleted: data['userContentDeleted'] == true,
        storageDeleted: data['storageDeleted'] == true,
        messengerMessagesAnonymized:
            data['messengerMessagesAnonymized'] == true,
        conversationsAnonymized: data['conversationsAnonymized'] == true,
        confirmationEmailSent: data['confirmationEmailSent'] == true,
      );
    } on AccountDeletionException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw AccountDeletionException(
        code: error.code,
        message: _messageForFunctionsError(error),
      );
    }
  }

  String _messageForFunctionsError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Deine Anmeldung ist nicht mehr aktiv. Bitte melde dich erneut an.';
      case 'failed-precondition':
        return 'Bitte bestätige deine Anmeldung erneut und versuche die Kontolöschung noch einmal.';
      case 'permission-denied':
        return 'Die Kontolöschung wurde aus Sicherheitsgründen nicht freigegeben.';
      case 'deadline-exceeded':
        return 'Die Kontolöschung hat zu lange gedauert. Bitte prüfe zuerst, ob dein Konto noch besteht.';
      case 'unavailable':
        return 'Luma konnte den Löschdienst gerade nicht erreichen. Bitte versuche es später erneut.';
      case 'internal':
        return 'Dein Konto konnte serverseitig nicht vollständig gelöscht werden. Bitte versuche es erneut.';
      default:
        final message = error.message?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        return 'Dein Konto konnte nicht gelöscht werden.';
    }
  }
}

class AccountDeletionResult {
  const AccountDeletionResult({
    required this.userId,
    required this.profileDeleted,
    required this.userContentDeleted,
    required this.storageDeleted,
    required this.messengerMessagesAnonymized,
    required this.conversationsAnonymized,
    required this.confirmationEmailSent,
  });

  final String userId;
  final bool profileDeleted;
  final bool userContentDeleted;
  final bool storageDeleted;
  final bool messengerMessagesAnonymized;
  final bool conversationsAnonymized;
  final bool confirmationEmailSent;
}

class AccountDeletionException implements Exception {
  const AccountDeletionException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => message;
}
