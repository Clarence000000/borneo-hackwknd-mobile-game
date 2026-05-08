import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:farm_fintech/firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/screens/game_screen.dart';
import 'package:farm_fintech/screens/login_screen.dart';
import 'package:farm_fintech/services/firestore_service.dart';
import 'package:farm_fintech/widgets/notification_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force landscape orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Hide system UI for immersive game experience
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Initialize Environment Variales
  await dotenv.load(fileName: ".env.local");

  // Initialize Firebase using custom configuration from env variables
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Connect to Firebase Emulators in debug mode
 /* 
  if (kDebugMode) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8081);
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  }
  */

  runApp(const FarmFintechApp());
}

class FarmFintechApp extends StatelessWidget {
  const FarmFintechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameState(),
      child: MaterialApp(
        title: 'Richi Farm',
        debugShowCheckedModeBanner: false,
        theme: GameTheme.darkTheme,
        home: const _EntryPoint(),
        builder: (context, child) {
          return Stack(
            children: [
              child!,
              const NotificationOverlay(),
            ],
          );
        },
      ),
    );
  }
}

/// Entry point that checks authentication state to route to LoginScreen or GameScreen
class _EntryPoint extends StatelessWidget {
  const _EntryPoint();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: GameColors.uiBackground,
            body: Center(child: CircularProgressIndicator(color: GameColors.uiGold)),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          // User logged out — wipe all game state so the next login
          // doesn't inherit a stale UID, timers, or Firestore listeners.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<GameState>().resetForLogout();
          });
          return const LoginScreen();
        }

        // We have an authenticated user, but we need to fetch their profile 
        // before launching the game since GameState depends on Player.
        //
        // Using ValueKey(user.uid) forces Flutter to rebuild the FutureBuilder
        // when switching between accounts, preventing stale data carry-over.
        return FutureBuilder<Player?>(
          key: ValueKey(user.uid),
          future: FirestoreService().getPlayer(user.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
               return const Scaffold(
                 backgroundColor: GameColors.uiBackground,
                 body: Center(child: CircularProgressIndicator(color: GameColors.uiGreen)),
               );
            }
            
            final player = userSnapshot.data;
            if (player == null) {
               // Logged in but no profile exists, probably an error state during registration, 
               // so just show Login screen securely.
               FirebaseAuth.instance.signOut();
               return const LoginScreen();
            }

            // Set provider state and route to Game.
            // Use UniqueKey so a fresh GameScreen (and thus fresh RichiFarmGame)
            // is always created for each user session.
            WidgetsBinding.instance.addPostFrameCallback((_) {
               context.read<GameState>().setPlayer(player);
            });
            return GameScreen(key: ValueKey('game_${user.uid}'));
          },
        );
      },
    );
  }
}
