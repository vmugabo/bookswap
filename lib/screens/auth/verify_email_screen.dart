import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _sending = false;
  bool _checking = false;

  Future<void> _sendVerification() async {
    setState(() => _sending = true);
    try {
      await ref.read(authServiceProvider).sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Verification email sent.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _sending = false);
  }

  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      await user?.reload();
      final reloaded = ref.read(firebaseAuthProvider).currentUser;
      if (reloaded != null && reloaded.emailVerified) {
        // Force refresh of auth state
        // No explicit action required; authStateChanges stream will emit
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Email not yet verified.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _checking = false);
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verify your email')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 24),
            Text(
              'A verification email was sent to your address. Please check your inbox and click the link.\n\nAfter verifying, come back and tap "I have verified" to continue.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
            ElevatedButton(
                onPressed: _sending ? null : _sendVerification,
                child: _sending
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Resend verification email')),
            SizedBox(height: 12),
            ElevatedButton(
                onPressed: _checking ? null : _checkVerified,
                child: _checking
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('I have verified')),
            SizedBox(height: 12),
            TextButton(onPressed: _signOut, child: Text('Sign out'))
          ],
        ),
      ),
    );
  }
}
