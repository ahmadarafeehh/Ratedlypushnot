import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:helloworld/screens/signup/age_screen.dart';
import 'package:helloworld/screens/signup/signup_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  Timer? _verificationTimer;
  Timer? _cooldownTimer;
  int _remainingTime = 50;
  int _cooldownSeconds = 0;
  User? _user;
  bool _isResending = false;
  late DateTime _screenStartTime;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _screenStartTime = DateTime.now();
    WidgetsBinding.instance.addObserver(this);

    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SignupScreen()),
          );
        }
      } else {
        if (_user == null) {
          _user = user;
          _initializeVerification();
        }
      }
    });
  }

  void _initializeVerification() {
    _startTimers();
    _checkEmailVerified();
  }

  void _startTimers() {
    _verificationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkEmailVerified();
      _checkAutoDeletion();
    });

    Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = DateTime.now().difference(_screenStartTime).inSeconds;
      setState(() => _remainingTime = 50 - elapsed);
    });
  }

  void _checkAutoDeletion() {
    final elapsed = DateTime.now().difference(_screenStartTime).inSeconds;
    if (elapsed >= 50) {
      _deleteUser();
    }
  }

  Future<void> _deleteUser() async {
    try {
      if (_user != null) {
        await _user!.delete();
        if (mounted) _navigateToSignup();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        await _handleExpiredSession();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deletion failed: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleExpiredSession() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please sign up again.')),
      );
      _navigateToSignup();
    }
  }

  Future<void> _checkEmailVerified() async {
    try {
      if (_user != null) {
        await _user!.reload();
        final updatedUser = FirebaseAuth.instance.currentUser;
        if (updatedUser?.emailVerified ?? false) {
          if (mounted) _navigateToProfileSetup();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification check failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_user == null) return;
    setState(() {
      _isResending = true;
      _cooldownSeconds = 50;
    });

    _cooldownTimer?.cancel();

    try {
      await _user!.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New verification email sent!')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Too many requests. Please wait.')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Resend failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  void _navigateToProfileSetup() {
    _cleanupTimers();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AgeVerificationScreen()),
        (route) => false,
      );
    }
  }

  void _handleChangeEmail() {
    _deleteUser();
  }

  void _navigateToSignup() {
    _cleanupTimers();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignupScreen()),
      );
    }
  }

  void _cleanupTimers() {
    _verificationTimer?.cancel();
    _cooldownTimer?.cancel();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cleanupTimers();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkEmailVerified();
      _checkAutoDeletion();
    }
  }

  String _formatTime(int seconds) {
    final displaySeconds = seconds.clamp(0, 50);
    final minutes = (displaySeconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (displaySeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFd9d9d9)),
          onPressed: () => _navigateToSignup(),
        ),
        title: const Text(
          'Verify Email',
          style: TextStyle(
            color: Color(0xFFd9d9d9),
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset(
              'assets/logo/22.png',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 20),
            const Text(
              'Verification Email Sent',
              style: TextStyle(
                color: Color(0xFFd9d9d9),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _user?.email ?? 'your email',
                style: const TextStyle(
                  color: Color(0xFFd9d9d9),
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Link expires in: ${_formatTime(_remainingTime)}',
              style: const TextStyle(
                color: Color(0xFFd9d9d9),
                fontSize: 14,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF333333),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: (_cooldownSeconds == 0 && !_isResending)
                  ? _resendVerificationEmail
                  : null,
              child: _isResending
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  : Text(
                      _cooldownSeconds > 0
                          ? 'Resend in $_cooldownSeconds seconds'
                          : 'Resend Email',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _handleChangeEmail,
              child: const Text(
                'Change Email Address',
                style: TextStyle(
                  color: Color(0xFFd9d9d9),
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
