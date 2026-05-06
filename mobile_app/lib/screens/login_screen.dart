import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _apiService = ApiService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  bool _isLoading = false;

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      await _googleSignIn.signOut();
      print('GoogleSignIn signed out to reset account chooser');
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      print('GoogleSignIn account: $account');
      if (account != null) {
        final GoogleSignInAuthentication auth = await account.authentication;
        print(
          'GoogleSignIn auth: idToken=${auth.idToken != null}, accessToken=${auth.accessToken != null}',
        );
        if (auth.idToken != null || auth.accessToken != null) {
          final user = await _apiService.googleLogin(
            idToken: auth.idToken,
            accessToken: auth.accessToken,
          );
          
          // SAVE SESSION FOR AUTO-LOGIN
          await SessionManager.saveSession(user, token: auth.idToken ?? auth.accessToken);
          print('[LoginScreen] Session saved for auto-login');
          
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/home', arguments: user);
          return;
        }
      }
      // If we got here, sign in was cancelled or failed without throwing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Sign-In canceled.')),
        );
      }
    } catch (e, st) {
      print('Google Sign-In exception: $e');
      print(st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google Sign-In failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              SvgPicture.asset(
                'assets/logo.svg',
                height: 100,
              ),
              const SizedBox(height: 24),
              Text(
                'Nirmitha',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Contractor Management Made Simple',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 48),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleGoogleLogin,
                            icon: const Icon(
                              Icons.mail_outline,
                              size: 24,
                            ),
                            label: const Flexible(
                              child: Text(
                                'Sign In with Gmail',
                                textAlign: TextAlign.center,
                                softWrap: true,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 32),
              Text(
                '© 2026 Nirmitha. All rights reserved.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
