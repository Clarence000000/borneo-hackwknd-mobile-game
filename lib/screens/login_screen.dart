import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/screens/game_screen.dart';
import 'package:farm_fintech/services/auth_service.dart';
import 'package:farm_fintech/widgets/book_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  
  bool _isRegistering = false;
  bool _isLoading = false;
  bool _isBookOpen = false;

  late AnimationController _openController;
  late Animation<double> _openAnimation;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _openAnimation = CurvedAnimation(
      parent: _openController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _openController.dispose();
    super.dispose();
  }

  void _openBook() {
    if (!_isBookOpen) {
      setState(() => _isBookOpen = true);
      _openController.forward();
    }
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
    
    // Animate zoom to game
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const GameScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final zoomAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInCirc,
          );
          return ScaleTransition(
            scale: Tween<double>(begin: 0.5, end: 1.0).animate(zoomAnimation),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // The background game view (dimmed)
          const Opacity(
            opacity: 0.3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/bank.png'), // Just a thematic backdrop
                  fit: BoxFit.cover,
                ),
              ),
              child: SizedBox.expand(),
            ),
          ),

          // The Animated Book
          AnimatedBuilder(
            animation: _openAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // The actual Login Form (revealed as cover opens)
                  if (_isBookOpen)
                    Opacity(
                      opacity: _openAnimation.value,
                      child: Transform.scale(
                        scale: 0.8 + (0.2 * _openAnimation.value),
                        child: Center(
                          child: Container(
                            width: 420,
                            constraints: const BoxConstraints(maxHeight: 650),
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4E4BC), // Parchment color
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 15,
                                  offset: const Offset(5, 5),
                                ),
                              ],
                              border: Border.all(color: const Color(0xFF5D4037), width: 3),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset('assets/images/logo.png', height: 100),
                                  const SizedBox(height: 16),
                                  Text(
                                    _isRegistering ? 'Farmer Registry' : 'Portal Login',
                                    style: GoogleFonts.cinzel(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (_isRegistering)
                                    _EntryField(
                                      controller: _nameCtrl,
                                      label: 'Farmer Name',
                                      icon: Icons.person_outline,
                                    ),
                                  if (_isRegistering) const SizedBox(height: 16),
                                  _EntryField(
                                    controller: _emailCtrl,
                                    label: 'Email Scroll',
                                    icon: Icons.email_outlined,
                                  ),
                                  const SizedBox(height: 16),
                                  _EntryField(
                                    controller: _passCtrl,
                                    label: 'Secret Password',
                                    icon: Icons.lock_outline,
                                    obscure: true,
                                  ),
                                  const SizedBox(height: 32),
                                  if (_isLoading)
                                    const CircularProgressIndicator(color: Color(0xFF5D4037))
                                  else
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF5D4037),
                                          foregroundColor: const Color(0xFFF4E4BC),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                        ),
                                        onPressed: _submit,
                                        child: Text(
                                          _isRegistering ? 'Register' : 'Login',
                                          style: GoogleFonts.cinzel(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                          ),
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
                                      style: GoogleFonts.almendra(
                                        color: textColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setState(() => _isBookOpen = false);
                                      _openController.reverse();
                                    },
                                    child: Text(
                                      'Close Book',
                                      style: GoogleFonts.cinzel(
                                        color: textColor.withOpacity(0.5),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // The Book Cover
                  if (_openAnimation.value < 1.0)
                    Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // perspective
                        ..rotateY(-1.5 * _openAnimation.value), // Open rotation
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: _openBook,
                        child: _BookCoverWidget(isOpening: _isBookOpen),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BookCoverWidget extends StatelessWidget {
  final bool isOpening;
  const _BookCoverWidget({required this.isOpening});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 450,
      height: 600,
      decoration: BoxDecoration(
        color: const Color(0xFF3D2B1F), // Rich dark brown leather
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 20,
            offset: const Offset(10, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFF2D1B10), width: 4),
      ),
      child: Stack(
        children: [
          // Golden Corner Ornaments
          Positioned(
            top: 20,
            right: 20,
            child: Icon(Icons.shield, color: const Color(0xFFC5A059).withOpacity(0.5), size: 40),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Icon(Icons.shield, color: const Color(0xFFC5A059).withOpacity(0.5), size: 40),
          ),
          
          // Center Title
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/logo.png', height: 180),
                const SizedBox(height: 40),
                Text(
                  'RICHI FARM',
                  style: GoogleFonts.cinzel(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFC5A059),
                    letterSpacing: 4.0,
                    shadows: [
                      const Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'CHRONICLES OF WEALTH',
                  style: GoogleFonts.almendra(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFC5A059).withOpacity(0.7),
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 60),
                if (!isOpening)
                  Text(
                    'TAP TO OPEN',
                    style: GoogleFonts.cinzel(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFC5A059).withOpacity(0.5),
                    ),
                  ),
              ],
            ),
          ),

          // Spine detailing
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 15,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;

  const _EntryField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.almendra(
        color: textColor,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cinzel(color: textColor.withOpacity(0.6), fontWeight: FontWeight.bold),
        prefixIcon: Icon(icon, color: textColor.withOpacity(0.6)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF5D4037)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF5D4037), width: 2),
        ),
      ),
    );
  }
}
