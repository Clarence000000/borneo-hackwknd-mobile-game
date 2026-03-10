import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/screens/game_screen.dart';
import 'package:farm_fintech/widgets/dialog_popup.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force landscape orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Hide system UI for immersive game experience
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // TODO: Initialize Firebase when configured
  // await Firebase.initializeApp();

  runApp(const FarmFintechApp());
}

class FarmFintechApp extends StatelessWidget {
  const FarmFintechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameState(),
      child: MaterialApp(
        title: 'Farm FinTech',
        debugShowCheckedModeBanner: false,
        theme: GameTheme.darkTheme,
        home: const _EntryPoint(),
      ),
    );
  }
}

/// Entry point that injects demo player and handles first-time tutorial.
class _EntryPoint extends StatefulWidget {
  const _EntryPoint();

  @override
  State<_EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<_EntryPoint> {
  @override
  void initState() {
    super.initState();

    // Inject a demo player for now (Firebase Auth will replace this)
    final state = context.read<GameState>();
    state.player = Player(
      uid: 'demo-user',
      displayName: 'Demo Farmer',
      country: 'MY',
      currency: 'XMYR',
    );

    // Show tutorial on first login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!(state.player?.tutorialCompleted ?? true)) {
        _showTutorial();
      }
    });
  }

  void _showTutorial() {
    DialogPopup.show(
      context,
      title: '🌾 Welcome to Farm FinTech!',
      message:
          'Welcome, farmer! Here\'s how to play:\n\n'
          '1. TAP a brown farmland tile to plant crops\n'
          '2. TAP "Next Day" ☀️ to advance time and grow crops\n'
          '3. HARVEST mature crops to earn money\n'
          '4. Visit the BANK for loans and insurance\n'
          '5. Use the MERCHANT for BNPL equipment\n\n'
          'Watch out for real-world weather disasters!',
      icon: Icons.agriculture,
      buttonText: 'Let\'s Farm! 🚜',
    ).then((_) {
      if (!mounted) return;
      final state = context.read<GameState>();
      state.player?.tutorialCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return const GameScreen();
  }
}
