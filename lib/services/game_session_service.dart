import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class GameStep {
  final int stepNumber;
  final int cellIndex;
  final String player; // 'player1' or 'player2'
  final int questionId;
  final String questionText;
  final List<String> options;
  final String correctAnswer;
  final String selectedAnswer;
  final bool isCorrect;
  final double timeSpent;
  final DateTime timestamp;

  GameStep({
    required this.stepNumber,
    required this.cellIndex,
    required this.player,
    required this.questionId,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.selectedAnswer,
    required this.isCorrect,
    required this.timeSpent,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'stepNumber': stepNumber,
        'cellIndex': cellIndex,
        'player': player,
        'questionId': questionId,
        'questionText': questionText,
        'options': options,
        'correctAnswer': correctAnswer,
        'selectedAnswer': selectedAnswer,
        'isCorrect': isCorrect,
        'timeSpent': timeSpent,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GameStep.fromJson(Map<String, dynamic> json) => GameStep(
        stepNumber: json['stepNumber'] as int,
        cellIndex: json['cellIndex'] as int,
        player: json['player'] as String,
        questionId: json['questionId'] as int? ?? 0,
        questionText: json['questionText'] as String? ?? '',
        options: (json['options'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        correctAnswer: json['correctAnswer'] as String? ?? '',
        selectedAnswer: json['selectedAnswer'] as String? ?? '',
        isCorrect: json['isCorrect'] as bool? ?? false,
        timeSpent: (json['timeSpent'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
}

class SavedGameState {
  final String version;
  final String gameState; // 'playing', 'gameOver', etc.
  final String currentPlayer; // 'player1', 'player2'
  final int player1Score;
  final double player1TotalTime;
  final List<int> player1OccupiedCells;
  final int player2Score;
  final double player2TotalTime;
  final List<int> player2OccupiedCells;
  final List<String?> gameBoard; // 25 elements: null, 'player1', 'player2'
  final int gameDuration;
  final int remainingTime;
  final List<int> answeredQuestionIds;
  final List<GameStep> steps;
  final DateTime lastSaved;

  SavedGameState({
    this.version = '1.0',
    required this.gameState,
    required this.currentPlayer,
    required this.player1Score,
    required this.player1TotalTime,
    required this.player1OccupiedCells,
    required this.player2Score,
    required this.player2TotalTime,
    required this.player2OccupiedCells,
    required this.gameBoard,
    required this.gameDuration,
    required this.remainingTime,
    required this.answeredQuestionIds,
    required this.steps,
    required this.lastSaved,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'gameState': gameState,
        'currentPlayer': currentPlayer,
        'player1Score': player1Score,
        'player1TotalTime': player1TotalTime,
        'player1OccupiedCells': player1OccupiedCells,
        'player2Score': player2Score,
        'player2TotalTime': player2TotalTime,
        'player2OccupiedCells': player2OccupiedCells,
        'gameBoard': gameBoard,
        'gameDuration': gameDuration,
        'remainingTime': remainingTime,
        'answeredQuestionIds': answeredQuestionIds,
        'steps': steps.map((s) => s.toJson()).toList(),
        'lastSaved': lastSaved.toIso8601String(),
      };

  factory SavedGameState.fromJson(Map<String, dynamic> json) => SavedGameState(
        version: json['version'] as String? ?? '1.0',
        gameState: json['gameState'] as String? ?? 'playing',
        currentPlayer: json['currentPlayer'] as String? ?? 'player1',
        player1Score: json['player1Score'] as int? ?? 0,
        player1TotalTime: (json['player1TotalTime'] as num?)?.toDouble() ?? 0.0,
        player1OccupiedCells:
            (json['player1OccupiedCells'] as List<dynamic>?)
                    ?.map((e) => e as int)
                    .toList() ??
                [],
        player2Score: json['player2Score'] as int? ?? 0,
        player2TotalTime: (json['player2TotalTime'] as num?)?.toDouble() ?? 0.0,
        player2OccupiedCells:
            (json['player2OccupiedCells'] as List<dynamic>?)
                    ?.map((e) => e as int)
                    .toList() ??
                [],
        gameBoard: (json['gameBoard'] as List<dynamic>?)
                ?.map((e) => e as String?)
                .toList() ??
            List.filled(25, null),
        gameDuration: json['gameDuration'] as int? ?? 0,
        remainingTime: json['remainingTime'] as int? ?? 1800,
        answeredQuestionIds:
            (json['answeredQuestionIds'] as List<dynamic>?)
                    ?.map((e) => e as int)
                    .toList() ??
                [],
        steps: (json['steps'] as List<dynamic>?)
                ?.map((e) => GameStep.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        lastSaved: DateTime.tryParse(json['lastSaved'] as String? ?? '') ??
            DateTime.now(),
      );
}

class GameSessionService {
  static const String _fileName = 'current_game_session.json';

  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Automatically persists state whenever a step occurs or timer ticks
  static Future<void> saveCurrentGame(SavedGameState state) async {
    try {
      final file = await _getFile();
      final jsonString = jsonEncode(state.toJson());
      await file.writeAsString(jsonString, flush: true);
    } catch (e) {
      // Best-effort auto-save
    }
  }

  /// Checks if a saved in-progress game session exists
  static Future<bool> hasSavedGame() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return false;
      final json = jsonDecode(content) as Map<String, dynamic>;
      final state = SavedGameState.fromJson(json);
      // Valid if game is not empty and has steps or elapsed time
      return state.steps.isNotEmpty || state.gameDuration > 0;
    } catch (_) {
      return false;
    }
  }

  /// Loads the saved session state from disk
  static Future<SavedGameState?> loadSavedGame() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final json = jsonDecode(content) as Map<String, dynamic>;
      return SavedGameState.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Clears the saved session when a clean new game is intentionally started
  static Future<void> clearSavedGame() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
