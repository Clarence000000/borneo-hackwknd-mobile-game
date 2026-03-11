import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:farm_fintech/models/player.dart';

/// Service to handle AI coaching via Gemini API.
class GeminiService {
  late final GenerativeModel _model;
  bool _initialized = false;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );
      _initialized = true;
    }
  }

  /// Ask the financial advisor NPC for a tip based on player state.
  Future<String> getFinancialAdvice(Player player, String topic) async {
    if (!_initialized) {
      return "I seem to have lost my connection to headquarters. Remember to save your money!";
    }

    final prompt = '''
You are a snarky but helpful financial advisor in an ASEAN farming simulator game. 
The player's name is ${player.displayName}. They are from ${player.country}.
Their credit score is ${player.creditScore} (range 300-850).
Their cash balance is \$${player.cashBalance.toStringAsFixed(0)}.
Their bank balance is \$${player.bankBalance.toStringAsFixed(0)}.

The player just asked about: "$topic"

Give them a short, punchy piece of advice (max 2 sentences). Point out if they have low cash, or low credit score, or warn them about predatory loans/BNPL. Keep it conversational and slightly witty.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? "Remember to diversify your crops!";
    } catch (e) {
      return "The connection is bad today... Just keep farming and watch your credit score!";
    }
  }
}
