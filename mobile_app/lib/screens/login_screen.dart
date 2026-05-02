import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;

  Future<void> _handleLogin(String role) async {
    // For sample login, we'll just mock it or use the backend if a user exists
    // But since it's a sample, let's just navigate based on the button pressed
    
    Navigator.pushReplacementNamed(context, '/home', arguments: role);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Contractor DB',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select your role to continue',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 48),
            _buildLoginButton('Login as Owner', const Color(0xFF1E293B), () => _handleLogin('owner')),
            const SizedBox(height: 16),
            _buildLoginButton('Login as Supervisor', const Color(0xFF3B82F6), () => _handleLogin('supervisor')),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}
