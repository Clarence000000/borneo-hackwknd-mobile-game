import 'dart:developer' as developer;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/models/quest.dart';
import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/utils/currency_util.dart';
import 'dart:math' as math;

/// Result of a financial danger analysis by the Oracle NPC.
class OracleAnalysisResult {
  final bool isDangerous;
  final String warningMessage;
  final int trustScore; // 0-100

  const OracleAnalysisResult({
    required this.isDangerous,
    required this.warningMessage,
    required this.trustScore,
  });

  factory OracleAnalysisResult.safe() => const OracleAnalysisResult(
        isDangerous: false,
        warningMessage: '',
        trustScore: 75,
      );
}

/// Service to handle AI coaching via Gemini API.
class GeminiService {
  late final GenerativeModel _model;
  bool _initialized = false;

  GeminiService() {
    final rawKey = dotenv.env['GEMINI_API_KEY'];
    final apiKey = rawKey?.trim(); // Clean any trailing spaces/newlines
    
    developer.log('GeminiService Init. Key starts with: ${apiKey?.substring(0, 5)}...', name: 'GeminiService');
    
    if (apiKey != null && apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );
      _initialized = true;
      developer.log('GeminiService Initialized with key length: ${apiKey.length}', name: 'GeminiService');
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
Their cash balance is ${CurrencyUtil.format(player.cashBalance, player.country)}.
Their bank balance is ${CurrencyUtil.format(player.bankBalance, player.country)}.

The player just asked about: "$topic"

Give them a short, punchy piece of advice (max 2 sentences). Point out if they have low cash, or low credit score, or warn them about predatory loans/BNPL. Keep it conversational and slightly witty.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? "Remember to diversify your crops!";
    } catch (e) {
      developer.log('Financial Advice Error: $e', name: 'GeminiService');
      return "The connection is bad today... (Error: $e)";
    }
  }

  /// Analyze the player's financial situation and return a danger assessment.
  /// Used by the Oracle NPC for periodic monitoring.
  Future<OracleAnalysisResult> analyzeFinancialDanger({
    required Player player,
    required int activeBnplCount,
    required int activeLoanCount,
    required int currentDay,
    required String activeDisaster,
  }) async {
    if (!_initialized) {
      return OracleAnalysisResult.safe();
    }

    final prompt = '''
You are Lyra the Oracle, an ancient seer in a fantasy farming game who monitors the financial health of farmers.

Analyze this farmer's financial situation and respond ONLY in this exact format, nothing else:
TRUST_SCORE: [number 0-100]
IS_DANGEROUS: [true or false]
WARNING: [one sentence of direct, modern financial warning, or empty if not dangerous]

Player data:
- Name: ${player.displayName}, Country: ${player.country}
- Cash: ${CurrencyUtil.format(player.cashBalance, player.country)}
- Bank: ${CurrencyUtil.format(player.bankBalance, player.country)}
- Credit Score: ${player.creditScore}/850
- Active BNPL Plans: $activeBnplCount
- Active Loans: $activeLoanCount
- Current Game Day: $currentDay
- Active Disaster: $activeDisaster

Rules for TRUST_SCORE:
- Start at 75
- Deduct 20 if credit score < 400
- Deduct 10 if credit score 400-549
- Deduct 15 if cash < 100
- Deduct 10 if cash < 500
- Deduct 15 if active loans > 0 AND cash < monthly payment estimate
- Deduct 10 per BNPL plan beyond 1
- Deduct 10 if disaster is active
- Add 10 if credit score > 700
- Add 5 if bank balance > 2000
- Clamp result to 0-100

Rules for IS_DANGEROUS:
- true if TRUST_SCORE < 40, or cash < 50, or credit score < 350

Respond ONLY with the three lines above. No other text.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      return _parseAnalysisResult(text);
    } catch (e) {
      developer.log('Danger Analysis Error: $e', name: 'GeminiService');
      return OracleAnalysisResult.safe();
    }
  }

  /// Parse the structured response from the danger analysis.
  OracleAnalysisResult _parseAnalysisResult(String text) {
    int trustScore = 75;
    bool isDangerous = false;
    String warning = '';

    for (final line in text.split('\n')) {
      if (line.startsWith('TRUST_SCORE:')) {
        final value = int.tryParse(line.replaceAll('TRUST_SCORE:', '').trim());
        if (value != null) trustScore = value.clamp(0, 100);
      } else if (line.startsWith('IS_DANGEROUS:')) {
        isDangerous = line.toLowerCase().contains('true');
      } else if (line.startsWith('WARNING:')) {
        warning = line.replaceAll('WARNING:', '').trim();
      }
    }

    return OracleAnalysisResult(
      isDangerous: isDangerous,
      warningMessage: warning,
      trustScore: trustScore,
    );
  }

  /// Chat with Lyra the Oracle. Supports both Gemini and OpenRouter based on key.
  Future<String> chatWithOracle({
    required Player player,
    required int activeBnplCount,
    required int activeLoanCount,
    required int currentDay,
    required String activeDisaster,
    required List<Map<String, String>> chatHistory,
    required String userMessage,
    required int trustScore,
  }) async {
    if (!_initialized) {
      return "The connection to the realm of wisdom is severed... check your API keys, traveler.";
    }

    final prompt = '''
You are Lyra, a young, extroverted, and highly knowledgeable literature student in a fantasy ASEAN farming realm. You are active, friendly, and speak with the energy of a bright student who loves sharing wisdom. 

Your knowledge is strictly limited to this realm's systems:
- Crops: Wheat, Paddy, Corn (planting, harvesting, market prices).
- Finance: Cash, Bank (savings, interest), Credit Score, BNPL (Buy Now Pay Later), and Loans.
- Disasters: Flood, Storm, Drought and how they affect your farm.
- Strategy: How to use BNPL and loans wisely to grow your farm without falling into debt traps.

Guidelines for responding:
- Language: Extremely easy to understand. No jargon.
- Length: Be precise and concise. Maximum 2-3 sentences.
- Tone: Friendly, energetic student. Use accessible but educated language.
- Strategy: Provide clear, actionable solutions for the farmer's financial health. You know everything about the game's mechanics, including interest rates and penalties.

Current farmer status:
- Name: ${player.displayName}, Realm: ${player.country}
- Gold (Cash): ${CurrencyUtil.format(player.cashBalance, player.country)}
- Vault (Bank): ${CurrencyUtil.format(player.bankBalance, player.country)}
- Credit Aura: ${player.creditScore}/850
- Active Debt Scrolls (BNPL): $activeBnplCount
- Loan Bonds: $activeLoanCount
- Day of the Realm: $currentDay
- Chaos in the Sky: $activeDisaster
- Financial Trust Score: $trustScore/100

Conversation history:
${chatHistory.map((m) => "${m['role'] == 'user' ? 'Farmer' : 'Lyra'}: ${m['content']}").join('\n')}

Farmer ${player.displayName} now asks: "$userMessage"
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? "The stars speak in silence this eve... seek wisdom another moment.";
    } catch (e) {
      developer.log('Gemini API Error: $e', name: 'GeminiService', error: e);
      return "The connection is bad today... (Error: $e)";
    }
  }

  /// Generate a new logically sound quest for the player.
  /// Pass [disasterContext] for an urgent market demand quest.
  /// Pass [locationContext] for a location exploration quest.
  Future<Quest> generateQuest({
    required Player player,
    required int currentDay,
    required int activeBnplCount,
    String? disasterContext,
    String? locationContext,
  }) async {
    if (!_initialized) {
      if (locationContext != null) {
        return Quest(
          id: 'q-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Forest Expedition',
          description: 'The Oracle of the Wild Forest awaits you. Visit the forest and speak with her.',
          type: QuestType.location,
          goalAmount: 1,
          targetLocation: 'wild_forest',
          startDay: currentDay,
          durationDays: 3,
          cost: 50,
          reward: 300,
        );
      }
      return Quest(
        id: 'q-${DateTime.now().millisecondsSinceEpoch}',
        title: disasterContext != null ? 'Emergency Delivery' : 'Simple Harvest',
        description: disasterContext != null
            ? '$disasterContext Deliver 10 crops urgently!'
            : 'Harvest 5 Wheat to prove your basic farming skills.',
        type: disasterContext != null ? QuestType.urgent : QuestType.harvest,
        goalAmount: disasterContext != null ? 10 : 5,
        targetCrop: disasterContext != null ? CropType.rice : CropType.wheat,
        startDay: currentDay,
        durationDays: disasterContext != null ? 1 : 3,
        cost: 50,
        reward: disasterContext != null ? 150 : 200,
      );
    }

    final marketEvent = disasterContext != null
        ? '''
MARKET EVENT: $disasterContext
Generate an URGENT market demand quest. Use type "urgent" or "delivery".
Set durationDays to 1 or 2 (half the normal window).
Set reward to exactly 3 times the cost.
'''
        : '';

    final locationEvent = locationContext != null
        ? '''
LOCATION EVENT: $locationContext
Generate a quest with type "location" and targetLocation "wild_forest".
Set goalAmount to 1. Set durationDays to 3.
'''
        : '';

    final prompt = '''
You are Lyra, a literature student and financial advisor. Generate a CHALLENGING but FAIR quest for this farmer.
The quest should encourage wise use of BNPL or Loans to grow the farm.

Farmer: ${player.displayName}
Day: $currentDay
Cash: ${player.cashBalance}
Credit: ${player.creditScore}
$marketEvent$locationEvent
Output ONLY this exact JSON format:
{
  "title": "Short catchy title",
  "description": "Short explanation of the challenge",
  "type": "harvest" OR "cash" OR "delivery" OR "urgent" OR "location",
  "goalAmount": number,
  "targetCrop": "wheat" OR "rice" OR "corn" (null if type is cash or location),
  "targetLocation": "wild_forest" (only if type is location, otherwise null),
  "durationDays": number (2-5, or 1-2 if urgent),
  "cost": number (payment to start),
  "reward": number (2x to 4x of cost, or exactly 3x if urgent/delivery)
}
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}') + 1;
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final jsonStr = text.substring(jsonStart, jsonEnd);
        final map = _parseJsonMap(jsonStr);
        if (map != null) {
          return Quest(
            id: 'q-${DateTime.now().millisecondsSinceEpoch}',
            title: map['title'] ?? 'Challenge',
            description: map['description'] ?? '',
            type: _parseQuestType(map['type']),
            goalAmount: (map['goalAmount'] as num?)?.toDouble() ?? 5.0,
            targetCrop: map['targetCrop'] != null ? _parseCropType(map['targetCrop']) : null,
            targetLocation: map['targetLocation'] as String?,
            startDay: currentDay,
            durationDays: (map['durationDays'] as num?)?.toInt() ?? 3,
            cost: (map['cost'] as num?)?.toDouble() ?? 100.0,
            reward: (map['reward'] as num?)?.toDouble() ?? 300.0,
          );
        }
      }
    } catch (e) {
      developer.log('Quest Generation Error: $e', name: 'GeminiService');
    }

    // Default fallback
    return Quest(
      id: 'q-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Emergency Harvest',
      description: 'The market needs rice! Harvest 10 Rice in 3 days.',
      type: QuestType.harvest,
      goalAmount: 10,
      targetCrop: CropType.rice,
      startDay: currentDay,
      durationDays: 3,
      cost: 100,
      reward: 400,
    );
  }

  Map<String, dynamic>? _parseJsonMap(String jsonStr) {
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      developer.log('JSON Parse Error: $e', name: 'GeminiService');
      return null;
    }
  }

  QuestType _parseQuestType(dynamic raw) {
    switch ((raw as String?)?.toLowerCase()) {
      case 'cash': return QuestType.cash;
      case 'delivery': return QuestType.delivery;
      case 'urgent': return QuestType.urgent;
      case 'location': return QuestType.location;
      default: return QuestType.harvest;
    }
  }

  CropType _parseCropType(String name) {
    switch (name.toLowerCase()) {
      case 'wheat': return CropType.wheat;
      case 'rice':
      case 'paddy': return CropType.rice;
      case 'corn': return CropType.corn;
      default: return CropType.wheat;
    }
  }
}
