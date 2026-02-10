import 'package:flutter/material.dart';

import '../strings.dart';

class AuthButtons extends StatelessWidget {
  const AuthButtons({
    super.key,
    required this.isLoading,
    required this.onSignIn,
    required this.onSignUp,
    required this.onGoogle,
    this.showGoogle = true,
  });

  final bool isLoading;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;
  final VoidCallback onGoogle;
  final bool showGoogle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isLoading ? null : onSignIn,
              child: const Text(Strings.signIn),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: isLoading ? null : onSignUp,
              child: const Text(Strings.signUp),
            ),
          ],
        ),
        if (showGoogle) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isLoading ? null : onGoogle,
            icon: const Icon(Icons.login),
            label: const Text(Strings.continueWithGoogle),
          ),
        ],
      ],
    );
  }
}
