// Pfad: lib/presentation/widgets/profile_feedback_helper.dart

import 'package:flutter/material.dart';

class ProfileFeedbackHelper {
  const ProfileFeedbackHelper._();

  static void showSnackBar({
    required BuildContext context,
    required String message,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
