import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/screens/game_screen.dart';
import 'package:farm_fintech/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  
  bool _isRegistering = false;
  bool _isLoading = false;

  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    try {
      if (_isRegistering) {
        final player = await _authService.register(email, pass, name);
        if (player != null && mounted) {
           _proceedToGame(player);
        } else if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registration Failed'))
           );
        }
      } else {
        final player = await _authService.signIn(email, pass);
        if (player != null && mounted) {
           _proceedToGame(player);
        } else if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Login Failed - Check credentials'))
           );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _proceedToGame(Player player) {
    context.read<GameState>().player = player;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.uiBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: GameColors.uiPanel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: GameColors.uiAccent),
              boxShadow: [
                BoxShadow(
                  color: GameColors.uiHighlight.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/logo.png', height: 100),
                const SizedBox(height: 16),
                const Text(
                  'Richi Farm',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: GameColors.uiText,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 32),

                if (_isRegistering)
                  TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: GameColors.uiText),
                    decoration: InputDecoration(
                      labelText: 'Farmer Name',
                      fillColor: GameColors.uiBackground,
                      filled: true,
                    ),
                  ),
                if (_isRegistering) const SizedBox(height: 16),

                TextField(
                  controller: _emailCtrl,
                  style: const TextStyle(color: GameColors.uiText),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    fillColor: GameColors.uiBackground,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  style: const TextStyle(color: GameColors.uiText),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    fillColor: GameColors.uiBackground,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 32),

                _isLoading
                    ? const CircularProgressIndicator(color: GameColors.uiGold)
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GameColors.uiGreen,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _submit,
                          child: Text(
                            _isRegistering ? 'Register' : 'Login',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () {
                    setState(() {
                      _isRegistering = !_isRegistering;
                      _nameCtrl.clear();
                      _passCtrl.clear();
                    });
                  },
                  child: Text(
                    _isRegistering
                        ? 'Already have an account? Login'
                        : 'New farmer? Create an account',
                    style: const TextStyle(color: GameColors.uiHighlight),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
