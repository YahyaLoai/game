import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import 'dart:async';
import 'package:game/database/app_database.dart';
import 'package:game/services/excel_service.dart';
import 'package:game/services/game_session_service.dart';
import 'package:game/screens/questions_page.dart';

enum GameState { waiting, playing, gameOver }

enum Player { player1, player2 }

class PlayerData {
  int score = 0;
  double totalTime = 0.0;
  List<int> occupiedCells = [];

  PlayerData();
}

enum WinLineType { horizontal, vertical, mainDiagonal, antiDiagonal }

class WinningLine {
  final WinLineType type;
  final int index;
  final List<int> cellIndices;

  WinningLine({
    required this.type,
    required this.index,
    required this.cellIndices,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  Timer? _gameTimer;
  Timer? _displayTimer;
  AnimationController? _lineAnimationController;
  Animation<double>? _lineAnimation;

  // Game state
  GameState gameState = GameState.waiting;
  Player currentPlayer = Player.player1;

  // Player data
  PlayerData player1Data = PlayerData();
  PlayerData player2Data = PlayerData();

  // Game board (5x5 = 25 cells)
  List<Player?> gameBoard = List.filled(25, null);
  Player? winner;
  WinningLine? winningLine;
  String winMessage = '';

  // Questions from Drift Database
  List<Map<String, dynamic>> gameQuestions = [];
  bool isLoadingQuestions = true;

  // Game steps history for recovery & audit
  List<GameStep> gameSteps = [];
  bool hasRecoverableSession = false;

  // Game duration
  int gameDuration = 0;

  // Scale factor for projector & screen sizing (0.6 to 1.25)
  double _displayScale = 0.85;

  // Font size controllers
  double _questionFontSize = 20.0;
  double _optionsFontSize = 16.0;
  double _cellFontSize = 35.0;
  double _headerFontSize = 24.0;

  // Global game time limit (30 minutes = 1800 seconds)
  static const int gameTimeLimit = 1800;
  int remainingTime = gameTimeLimit;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _lineAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _lineAnimation = CurvedAnimation(
      parent: _lineAnimationController!,
      curve: Curves.easeInOutCubic,
    );
    _initDatabaseAndQuestions();
  }

  Future<void> _initDatabaseAndQuestions() async {
    await ExcelService.seedDefaultQuestionsIfEmpty();
    await _loadQuestionsFromDb();
    
    // Check if an existing game session can be recovered
    final hasSaved = await GameSessionService.hasSavedGame();
    if (hasSaved && mounted) {
      setState(() {
        hasRecoverableSession = true;
      });
      _showRecoveryPrompt();
    } else {
      _startNewGame(resetHistory: true);
    }
  }

  Future<void> _loadQuestionsFromDb() async {
    final dbQuestions = await appDatabase.getAllQuestions();
    setState(() {
      gameQuestions = dbQuestions
          .map(
            (q) => {
              'id': q.id,
              'question': q.question,
              'options': <String>[q.optionA, q.optionB, q.optionC, q.optionD],
              'answer': q.answerNumber == 1
                  ? q.optionA
                  : q.answerNumber == 2
                  ? q.optionB
                  : q.answerNumber == 3
                  ? q.optionC
                  : q.optionD,
              'answerNumber': q.answerNumber,
              'isAnswer': false,
            },
          )
          .toList();
      isLoadingQuestions = false;
    });
  }

  Future<void> _openQuestionsPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QuestionsPage()),
    );
    await _loadQuestionsFromDb();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _lineAnimationController?.dispose();
    _gameTimer?.cancel();
    _displayTimer?.cancel();
    super.dispose();
  }

  void _showRecoveryPrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF764BA2), width: 1.5),
          ),
          title: Row(
            children: const [
              Icon(Icons.history, color: Colors.amberAccent, size: 28),
              SizedBox(width: 10),
              Text(
                'استرجاع جولة سابقة',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: const Text(
            'تم العثور على جولة مسابقة غير مكتملة محفوظة تلقائياً (في حال انطفأ الجهاز أو تم إغلاقه).\n\nهل ترغب في استئناف الجولة من آخر نقطة أم بدء لعبة جديدة بالكامل؟',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _startNewGame(resetHistory: true);
              },
              child: const Text('لعبة جديدة (تجاهل)', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _restoreSavedSession();
              },
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('استئناف اللعبة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _restoreSavedSession() async {
    final saved = await GameSessionService.loadSavedGame();
    if (saved == null) {
      _startNewGame(resetHistory: true);
      return;
    }

    setState(() {
      gameState = saved.gameState == 'gameOver'
          ? GameState.gameOver
          : GameState.playing;
      currentPlayer = saved.currentPlayer == 'player2'
          ? Player.player2
          : Player.player1;

      player1Data = PlayerData()
        ..score = saved.player1Score
        ..totalTime = saved.player1TotalTime
        ..occupiedCells = List<int>.from(saved.player1OccupiedCells);

      player2Data = PlayerData()
        ..score = saved.player2Score
        ..totalTime = saved.player2TotalTime
        ..occupiedCells = List<int>.from(saved.player2OccupiedCells);

      gameBoard = saved.gameBoard.map((val) {
        if (val == 'player1') return Player.player1;
        if (val == 'player2') return Player.player2;
        return null;
      }).toList();

      gameDuration = saved.gameDuration;
      remainingTime = saved.remainingTime;
      gameSteps = List<GameStep>.from(saved.steps);
      hasRecoverableSession = false;

      // Mark previously answered questions
      for (var q in gameQuestions) {
        if (saved.answeredQuestionIds.contains(q['id'])) {
          q['isAnswer'] = true;
        }
      }

      final win = _checkWin(Player.player1) ?? _checkWin(Player.player2);
      if (win != null) {
        winningLine = win;
        winner = _checkWin(Player.player1) != null ? Player.player1 : Player.player2;
      }
    });

    if (gameState == GameState.playing) {
      _startGameTimer();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم استرجاع الجولة بنجاح! تم تحميل ${gameSteps.length} خطوة سابقة.',
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _autoSaveCurrentSession() async {
    final answeredIds = gameQuestions
        .where((q) => q['isAnswer'] == true && q['id'] is int)
        .map((q) => q['id'] as int)
        .toList();

    final boardStrings = gameBoard.map((p) {
      if (p == Player.player1) return 'player1';
      if (p == Player.player2) return 'player2';
      return null;
    }).toList();

    final state = SavedGameState(
      gameState: gameState == GameState.gameOver ? 'gameOver' : 'playing',
      currentPlayer:
          currentPlayer == Player.player1 ? 'player1' : 'player2',
      player1Score: player1Data.score,
      player1TotalTime: player1Data.totalTime,
      player1OccupiedCells: List<int>.from(player1Data.occupiedCells),
      player2Score: player2Data.score,
      player2TotalTime: player2Data.totalTime,
      player2OccupiedCells: List<int>.from(player2Data.occupiedCells),
      gameBoard: boardStrings,
      gameDuration: gameDuration,
      remainingTime: remainingTime,
      answeredQuestionIds: answeredIds,
      steps: List<GameStep>.from(gameSteps),
      lastSaved: DateTime.now(),
    );

    await GameSessionService.saveCurrentGame(state);
  }

  Future<void> _rollbackToStep(int targetStepIndex) async {
    if (targetStepIndex < -1 || targetStepIndex >= gameSteps.length) return;

    // We reconstruct the entire board up to targetStepIndex
    final newBoard = List<Player?>.filled(25, null);
    final p1 = PlayerData();
    final p2 = PlayerData();
    final answeredIds = <int>{};
    final newSteps = <GameStep>[];

    for (int i = 0; i <= targetStepIndex; i++) {
      final step = gameSteps[i];
      newSteps.add(step);
      answeredIds.add(step.questionId);

      final p = step.player == 'player1' ? Player.player1 : Player.player2;
      if (step.isCorrect) {
        newBoard[step.cellIndex] = p;
        if (p == Player.player1) {
          p1.score++;
          p1.totalTime += step.timeSpent;
          p1.occupiedCells.add(step.cellIndex);
        } else {
          p2.score++;
          p2.totalTime += step.timeSpent;
          p2.occupiedCells.add(step.cellIndex);
        }
      } else {
        if (p == Player.player1) {
          p1.totalTime += step.timeSpent;
        } else {
          p2.totalTime += step.timeSpent;
        }
      }
    }

    // Determine whose turn it should be after the last executed step
    Player nextPlayer = Player.player1;
    if (newSteps.isNotEmpty) {
      final lastStep = newSteps.last;
      nextPlayer = lastStep.player == 'player1' ? Player.player2 : Player.player1;
    }

    setState(() {
      gameBoard = newBoard;
      player1Data = p1;
      player2Data = p2;
      gameSteps = newSteps;
      currentPlayer = nextPlayer;
      winner = null;
      winningLine = null;
      winMessage = '';
      gameState = GameState.playing;

      // Update question answered state
      for (var q in gameQuestions) {
        q['isAnswer'] = answeredIds.contains(q['id']);
      }
    });

    _lineAnimationController?.reset();
    await _autoSaveCurrentSession();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم الرجوع إلى الجولة رقم ${targetStepIndex + 1} بنجاح!',
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.blueAccent,
        ),
      );
    }
  }

  void _startNewGame({bool resetHistory = true}) {
    _lineAnimationController?.reset();
    setState(() {
      gameState = GameState.playing; // Start playing immediately
      currentPlayer = Player.player1;
      player1Data = PlayerData();
      player2Data = PlayerData();
      gameBoard = List.filled(25, null);
      winner = null;
      winningLine = null;
      winMessage = '';
      gameDuration = 0;
      remainingTime = gameTimeLimit;
      if (resetHistory) {
        gameSteps = [];
      }

      // Reset questions
      for (var question in gameQuestions) {
        question["isAnswer"] = false;
      }
    });

    if (resetHistory) {
      GameSessionService.clearSavedGame();
    } else {
      _autoSaveCurrentSession();
    }

    // Start the game timer
    _startGameTimer();
  }

  void _startGameTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && gameState == GameState.playing) {
        setState(() {
          // Update current player's time
          if (currentPlayer == Player.player1) {
            player1Data.totalTime += 1.0;
          } else {
            player2Data.totalTime += 1.0;
          }
        });
      } else if (gameState == GameState.gameOver) {
        timer.cancel();
      }
    });

    // Start display timer for UI updates
    _startDisplayTimer();
  }

  void _startDisplayTimer() {
    _displayTimer?.cancel();
    _displayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && gameState == GameState.playing) {
        setState(() {
          gameDuration++;
          remainingTime--;

          // Check if time is up
          if (remainingTime <= 0) {
            _handleTimeUp();
            timer.cancel();
          }

          // Show warning when time is running out
          if (remainingTime == 300 ||
              remainingTime == 180 ||
              remainingTime == 60) {
            _showTimeWarning(remainingTime);
          }

          // Periodic auto-save every 10 seconds to preserve time elapsed
          if (gameDuration % 10 == 0) {
            _autoSaveCurrentSession();
          }
        });
      } else if (gameState == GameState.gameOver) {
        timer.cancel();
      }
    });
  }

  void _handleTimeUp() {
    setState(() {
      gameState = GameState.gameOver;
      winMessage = 'انتهى الوقت!';
      _determineWinnerByPoints();
    });
    _stopGameTimer();

    // Show time up message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'انتهى الوقت! سيتم تحديد الفائز بالنقاط',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showTimeWarning(int remainingSeconds) {
    if (mounted) {
      String message;
      Color backgroundColor;

      if (remainingSeconds == 300) {
        message = '5 دقائق متبقية!';
        backgroundColor = Colors.orange;
      } else if (remainingSeconds == 180) {
        message = '3 دقائق متبقية!';
        backgroundColor = Colors.deepOrange;
      } else if (remainingSeconds == 60) {
        message = 'دقيقة واحدة متبقية!';
        backgroundColor = Colors.red;
      } else {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: backgroundColor,
        ),
      );
    }
  }

  void _showQuestionDialog(int cellIndex) {
    if (gameBoard[cellIndex] != null || gameState != GameState.playing) {
      return;
    }

    // Get random question
    final availableQuestions = gameQuestions
        .where((q) => q["isAnswer"] == false)
        .toList();
    if (availableQuestions.isEmpty) {
      _checkGameEnd();
      return;
    }

    final randomQuestion =
        availableQuestions[Random().nextInt(availableQuestions.length)];
    final questionIndex = gameQuestions.indexOf(randomQuestion);

    // Show a brief message before the question
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'دور ${currentPlayer == Player.player1 ? "اللاعب الأول" : "اللاعب الثاني"}!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: currentPlayer == Player.player1
            ? Colors.blue
            : Colors.red,
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => QuestionDialog(
        question: randomQuestion["question"] ?? '',
        options: List<String>.from(
          randomQuestion["options"] ?? const <String>[],
        ),
        answer: randomQuestion["answer"] ?? '',
        questionIndex: questionIndex,
        cellIndex: cellIndex,
        currentPlayer: currentPlayer,
        questionFontSize: _questionFontSize,
        optionsFontSize: _optionsFontSize,
        onAnswer: _handleAnswer,
      ),
    );
  }

  void _handleAnswer(
    int questionIndex,
    int cellIndex,
    String selectedAnswer,
    String correctAnswer,
    double timeSpent,
    Player player,
  ) {
    setState(() {
      gameQuestions[questionIndex]["isAnswer"] = true;

      if (selectedAnswer == correctAnswer) {
        // Correct answer - claim the cell
        gameBoard[cellIndex] = player;

        if (player == Player.player1) {
          player1Data.score++;
          player1Data.totalTime += timeSpent;
          player1Data.occupiedCells.add(cellIndex);
        } else {
          player2Data.score++;
          player2Data.totalTime += timeSpent;
          player2Data.occupiedCells.add(cellIndex);
        }

        _confettiController.play();

        // Check for win
        final win = _checkWin(player);
        if (win != null) {
          winningLine = win;
          winner = player;
          gameState = GameState.gameOver;
          winMessage = player == Player.player1
              ? 'اللاعب الأول فاز!'
              : 'اللاعب الثاني فاز!';
          _lineAnimationController?.forward(from: 0.0);
          _stopGameTimer();
        } else if (_checkDraw()) {
          gameState = GameState.gameOver;
          _determineWinnerByPoints();
          _stopGameTimer();
        } else {
          // Switch player
          currentPlayer = currentPlayer == Player.player1
              ? Player.player2
              : Player.player1;
        }
      } else if (selectedAnswer.isEmpty) {
        // Time up - no answer given, just switch player
        if (player == Player.player1) {
          player1Data.totalTime += timeSpent;
        } else {
          player2Data.totalTime += timeSpent;
        }

        currentPlayer = currentPlayer == Player.player1
            ? Player.player2
            : Player.player1;

        // Show time up message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'انتهى الوقت! دور ${currentPlayer == Player.player1 ? "اللاعب الأول" : "اللاعب الثاني"}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Wrong answer - just switch player
        if (player == Player.player1) {
          player1Data.totalTime += timeSpent;
        } else {
          player2Data.totalTime += timeSpent;
        }

        currentPlayer = currentPlayer == Player.player1
            ? Player.player2
            : Player.player1;
      }

      if (gameState == GameState.waiting) {
        gameState = GameState.playing;
      }

      // Record step in history
      final currentQuestion = gameQuestions[questionIndex];
      final step = GameStep(
        stepNumber: gameSteps.length + 1,
        cellIndex: cellIndex,
        player: player == Player.player1 ? 'player1' : 'player2',
        questionId: currentQuestion['id'] is int ? currentQuestion['id'] as int : 0,
        questionText: currentQuestion['question']?.toString() ?? '',
        options: List<String>.from(currentQuestion['options'] ?? const []),
        correctAnswer: correctAnswer,
        selectedAnswer: selectedAnswer,
        isCorrect: selectedAnswer == correctAnswer,
        timeSpent: timeSpent,
        timestamp: DateTime.now(),
      );
      gameSteps.add(step);
    });

    // Auto-save game state to disk for disaster recovery (shutdown / power off)
    _autoSaveCurrentSession();
  }

  WinningLine? _checkWin(Player player) {
    final playerCells = gameBoard
        .asMap()
        .entries
        .where((entry) => entry.value == player)
        .map((entry) => entry.key)
        .toSet();

    // Check for 5 in a row in any direction (horizontal, vertical, diagonal)

    // Check rows (horizontal)
    for (int row = 0; row < 5; row++) {
      final cells = List.generate(5, (col) => row * 5 + col);
      if (cells.every((cell) => playerCells.contains(cell))) {
        return WinningLine(
          type: WinLineType.horizontal,
          index: row,
          cellIndices: cells,
        );
      }
    }

    // Check columns (vertical)
    for (int col = 0; col < 5; col++) {
      final cells = List.generate(5, (row) => row * 5 + col);
      if (cells.every((cell) => playerCells.contains(cell))) {
        return WinningLine(
          type: WinLineType.vertical,
          index: col,
          cellIndices: cells,
        );
      }
    }

    // Check main diagonal (top-left to bottom-right)
    final mainDiag = [0, 6, 12, 18, 24];
    if (mainDiag.every((cell) => playerCells.contains(cell))) {
      return WinningLine(
        type: WinLineType.mainDiagonal,
        index: 0,
        cellIndices: mainDiag,
      );
    }

    // Check anti-diagonal (top-right to bottom-left)
    final antiDiag = [4, 8, 12, 16, 20];
    if (antiDiag.every((cell) => playerCells.contains(cell))) {
      return WinningLine(
        type: WinLineType.antiDiagonal,
        index: 0,
        cellIndices: antiDiag,
      );
    }

    return null;
  }

  bool _checkDraw() {
    return !gameBoard.contains(null) ||
        (gameQuestions.isNotEmpty &&
            gameQuestions.every((q) => q["isAnswer"] == true));
  }

  void _determineWinnerByPoints() {
    if (player1Data.score > player2Data.score) {
      winner = Player.player1;
      winMessage =
          'اللاعب الأول فاز بالنقاط! (${player1Data.score} - ${player2Data.score})';
    } else if (player2Data.score > player1Data.score) {
      winner = Player.player2;
      winMessage =
          'اللاعب الثاني فاز بالنقاط! (${player2Data.score} - ${player1Data.score})';
    } else {
      // Equal points, check time
      if (player1Data.totalTime < player2Data.totalTime) {
        winner = Player.player1;
        winMessage =
            'اللاعب الأول فاز بالوقت! (${player1Data.totalTime.toStringAsFixed(1)}s vs ${player2Data.totalTime.toStringAsFixed(1)}s)';
      } else if (player2Data.totalTime < player1Data.totalTime) {
        winner = Player.player2;
        winMessage =
            'اللاعب الثاني فاز بالوقت! (${player2Data.totalTime.toStringAsFixed(1)}s vs ${player1Data.totalTime.toStringAsFixed(1)}s)';
      } else {
        winMessage = 'التعادل!';
      }
    }
  }

  void _checkGameEnd() {
    if (_checkDraw()) {
      setState(() {
        gameState = GameState.gameOver;
        _determineWinnerByPoints();
      });
      _stopGameTimer();
    }
  }

  void _stopGameTimer() {
    _gameTimer?.cancel();
    _gameTimer = null;
    _displayTimer?.cancel();
    _displayTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
            ),
          ),
          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Game header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),
                          Text(
                            " XO المسابقة الوطنية للمعلومات",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _headerFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          // Steps / Rounds History Button
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.2,
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.history, color: Colors.amberAccent),
                              tooltip: 'سجل الجولات والرجوع لنقطة سابقة (${gameSteps.length})',
                              onPressed: _showGameHistoryDialog,
                            ),
                          ),
                          // Settings Icon Button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.2,
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.settings, color: Colors.white),
                              tooltip: 'الإعدادات (حجم العرض، الخطوط، الأسئلة)',
                              onPressed: _showSettingsDialog,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      if (gameState == GameState.playing)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              'وقت اللعبة: ${gameDuration ~/ 60}:${(gameDuration % 60).toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: remainingTime <= 300
                                    ? Colors.red
                                    : remainingTime <= 600
                                    ? Colors.orange
                                    : Colors.green,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'الوقت المتبقي: ${remainingTime ~/ 60}:${(remainingTime % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 10),
                      // Instructions for players
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'كيفية اللعب:',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'انقر على أي خلية للإجابة على سؤال. الإجابة الصحيحة تمنحك الخلية!',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (gameState == GameState.gameOver &&
                          winMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            winMessage,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),

                // Game board (5x5) and players - Scaled for projectors / screens
                Expanded(
                  child: Center(
                    child: Transform.scale(
                      scale: _displayScale,
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Player 1 section
                            SizedBox(
                              width: 220,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildPlayerCard(
                                    'اللاعب الأول',
                                    player1Data.score,
                                    player1Data.totalTime,
                                    currentPlayer == Player.player1 &&
                                        gameState == GameState.playing,
                                    Colors.blue,
                                  ),
                                  const SizedBox(height: 10),
                                  Image.asset(
                                    'lib/s.png',
                                    width: 280,
                                    height: 280,
                                    fit: BoxFit.contain,
                                  ),
                                ],
                              ),
                            ),

                            // Game board center
                            Center(
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 500,
                                  maxHeight: 500,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 5,
                                            childAspectRatio: 1,
                                            mainAxisSpacing: 4,
                                            crossAxisSpacing: 4,
                                          ),
                                      itemCount: 25,
                                      itemBuilder: (context, index) {
                                        return _buildGameCell(index);
                                      },
                                    ),
                                    if (winningLine != null &&
                                        _lineAnimation != null)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: AnimatedBuilder(
                                            animation: _lineAnimation!,
                                            builder: (context, child) {
                                              return CustomPaint(
                                                painter: WinningLinePainter(
                                                  winningLine: winningLine!,
                                                  progress:
                                                      _lineAnimation!.value,
                                                  winner: winner,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Player 2 section
                            SizedBox(
                              width: 220,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildPlayerCard(
                                    'اللاعب الثاني',
                                    player2Data.score,
                                    player2Data.totalTime,
                                    currentPlayer == Player.player2 &&
                                        gameState == GameState.playing,
                                    Colors.red,
                                  ),
                                  const SizedBox(height: 10),
                                  Image.asset(
                                    'lib/m.png',
                                    width: 280,
                                    height: 280,
                                    fit: BoxFit.contain,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Game controls
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _startNewGame,
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text(
                          'لعبة جديدة',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.95),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                      Text(
                        gameState == GameState.playing
                            ? 'دور ${currentPlayer == Player.player1 ? "اللاعب الأول (X)" : "اللاعب الثاني (O)"}'
                            : 'انتهت اللعبة',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(
    String name,
    int score,
    double time,
    bool isActive,
    Color color,
  ) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isActive
            ? color.withOpacity(0.3)
            : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: isActive ? Border.all(color: color, width: 3) : null,
      ),
      child: Column(
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'النقاط: $score',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          Text(
            'الوقت: ${time.toStringAsFixed(0)} ',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCell(int index) {
    final cellOwner = gameBoard[index];
    final isWinningCell = winningLine?.cellIndices.contains(index) ?? false;

    return GestureDetector(
      onTap: () {
        if (gameBoard[index] == null && gameState == GameState.playing) {
          // Add visual feedback
          HapticFeedback.lightImpact();
          _showQuestionDialog(index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: cellOwner == null
              ? Colors.white.withOpacity(0.9)
              : cellOwner == Player.player1
              ? Colors.blue.withOpacity(0.8)
              : Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(15),
          border: isWinningCell
              ? Border.all(color: Colors.amberAccent, width: 3.5)
              : null,
          boxShadow: [
            if (isWinningCell)
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.6),
                blurRadius: 14,
                spreadRadius: 2,
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Center(
          child: cellOwner == null
              ? Text(
                  (index + 1).toString(),
                  style: TextStyle(
                    fontSize: _cellFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Text(
                  cellOwner == Player.player1 ? 'X' : 'O',
                  style: TextStyle(
                    fontSize: _cellFontSize,
                    fontWeight: FontWeight.bold,
                    color: isWinningCell ? Colors.amberAccent : Colors.white,
                    shadows: isWinningCell
                        ? const [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 6,
                              offset: Offset(1, 2),
                            ),
                          ]
                        : null,
                  ),
                ),
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFF764BA2), width: 1.5),
              ),
              child: Container(
                width: 580,
                constraints: const BoxConstraints(maxHeight: 700),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.settings,
                            color: Colors.amberAccent,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'إعدادات العرض واللعبة (Settings)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 16),

                    // Scrollable content
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // SECTION 1: Questions Management
                            _buildSettingsSection(
                              title: 'إدارة الأسئلة',
                              icon: Icons.table_chart,
                              iconColor: const Color(0xFF4CAF50),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'بنك الأسئلة الحالي: ${gameQuestions.length} سؤال',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'استيراد أسئلة من Excel، إضافة، تعديل أو حذف الأسئلة',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        Navigator.of(ctx).pop();
                                        await _openQuestionsPage();
                                      },
                                      icon: const Icon(Icons.launch, size: 16),
                                      label: const Text('فتح بنك الأسئلة'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2E7D32),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // SECTION 2: Projector & Screen Scale
                            _buildSettingsSection(
                              title: 'حجم العرض للبروجكتر (${(_displayScale * 100).round()}%)',
                              icon: Icons.aspect_ratio,
                              iconColor: Colors.amberAccent,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline),
                                          color: Colors.white,
                                          tooltip: 'تصغير',
                                          onPressed: _displayScale > 0.55
                                              ? () {
                                                  final newVal = (_displayScale - 0.05).clamp(0.50, 1.25);
                                                  setState(() => _displayScale = newVal);
                                                  setModalState(() {});
                                                }
                                              : null,
                                        ),
                                        Expanded(
                                          child: SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              activeTrackColor: Colors.amberAccent,
                                              inactiveTrackColor: Colors.white24,
                                              thumbColor: Colors.amber,
                                              trackHeight: 5,
                                            ),
                                            child: Slider(
                                              value: _displayScale,
                                              min: 0.50,
                                              max: 1.25,
                                              divisions: 15,
                                              onChanged: (val) {
                                                setState(() => _displayScale = val);
                                                setModalState(() {});
                                              },
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline),
                                          color: Colors.white,
                                          tooltip: 'تكبير',
                                          onPressed: _displayScale < 1.25
                                              ? () {
                                                  final newVal = (_displayScale + 0.05).clamp(0.50, 1.25);
                                                  setState(() => _displayScale = newVal);
                                                  setModalState(() {});
                                                }
                                              : null,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        _buildPresetChip('بروجكتر صغير 65%', 0.65, setModalState),
                                        _buildPresetChip('بروجكتر 75%', 0.75, setModalState),
                                        _buildPresetChip('الافتراضي 85%', 0.85, setModalState),
                                        _buildPresetChip('شاشة 100%', 1.00, setModalState),
                                        _buildPresetChip('كبير 115%', 1.15, setModalState),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // SECTION 3: Font Size Controls
                            _buildSettingsSection(
                              title: 'أحجام الخطوط (Font Sizes)',
                              icon: Icons.format_size,
                              iconColor: const Color(0xFF64B5F6),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  children: [
                                    // Question font size
                                    _buildFontSizeSlider(
                                      label: 'خط السؤال في النافذة',
                                      value: _questionFontSize,
                                      min: 14.0,
                                      max: 32.0,
                                      onChanged: (val) {
                                        setState(() => _questionFontSize = val);
                                        setModalState(() {});
                                      },
                                    ),
                                    const Divider(color: Colors.white10, height: 16),
                                    // Options font size
                                    _buildFontSizeSlider(
                                      label: 'خط خيارات الإجابة',
                                      value: _optionsFontSize,
                                      min: 12.0,
                                      max: 24.0,
                                      onChanged: (val) {
                                        setState(() => _optionsFontSize = val);
                                        setModalState(() {});
                                      },
                                    ),
                                    const Divider(color: Colors.white10, height: 16),
                                    // Board cells font size
                                    _buildFontSizeSlider(
                                      label: 'خط الأرقام والرموز في اللوحة (X/O)',
                                      value: _cellFontSize,
                                      min: 20.0,
                                      max: 55.0,
                                      onChanged: (val) {
                                        setState(() => _cellFontSize = val);
                                        setModalState(() {});
                                      },
                                    ),
                                    const Divider(color: Colors.white10, height: 16),
                                    // Header font size
                                    _buildFontSizeSlider(
                                      label: 'خط عنوان المسابقة الرئيسي',
                                      value: _headerFontSize,
                                      min: 16.0,
                                      max: 36.0,
                                      onChanged: (val) {
                                        setState(() => _headerFontSize = val);
                                        setModalState(() {});
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _questionFontSize = 20.0;
                                            _optionsFontSize = 16.0;
                                            _cellFontSize = 35.0;
                                            _headerFontSize = 24.0;
                                          });
                                          setModalState(() {});
                                        },
                                        icon: const Icon(Icons.restore, size: 16, color: Colors.amberAccent),
                                        label: const Text(
                                          'استعادة الخطوط الافتراضية',
                                          style: TextStyle(color: Colors.amberAccent, fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action button
                    Align(
                      alignment: Alignment.center,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF764BA2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('حفظ وإغلاق', style: TextStyle(fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildFontSizeSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 5,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF64B5F6),
              inactiveTrackColor: Colors.white24,
              thumbColor: const Color(0xFF42A5F5),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).toInt(),
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${value.round()}px',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.amberAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(
    String label,
    double value,
    void Function(void Function()) setModalState,
  ) {
    final isSelected = (_displayScale - value).abs() < 0.02;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.amberAccent,
      backgroundColor: Colors.white.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black87 : Colors.white,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _displayScale = value);
          setModalState(() {});
        }
      },
    );
  }

  void _showGameHistoryDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFF764BA2), width: 1.5),
              ),
              child: Container(
                width: 680,
                constraints: const BoxConstraints(maxHeight: 720),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.history, color: Colors.amberAccent, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'سجل خطوات وجولات المسابقة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'إجمالي الخطوات المنفذة: ${gameSteps.length} | يمكنك الرجوع لأي خطوة سابقة',
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 12),

                    // List of steps or empty message
                    if (gameSteps.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'لم يتم تنفيذ أي جولات أو إجابات في هذه اللعبة بعد.',
                            style: TextStyle(color: Colors.white60, fontSize: 15),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: gameSteps.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            // Display in reverse order (latest first) or chronological
                            final step = gameSteps[index];
                            final row = (step.cellIndex ~/ 5) + 1;
                            final col = (step.cellIndex % 5) + 1;
                            final isP1 = step.player == 'player1';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: step.isCorrect
                                      ? (isP1 ? Colors.blue.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5))
                                      : Colors.grey.withValues(alpha: 0.3),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isP1 ? Colors.blue : Colors.red,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'جولة ${step.stepNumber}: ${isP1 ? "اللاعب الأول (X)" : "اللاعب الثاني (O)"}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'الخلية ${step.cellIndex + 1} (صف $row، عمود $col)',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: step.isCorrect
                                              ? Colors.green.withValues(alpha: 0.2)
                                              : Colors.red.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              step.isCorrect ? Icons.check_circle : Icons.cancel,
                                              size: 14,
                                              color: step.isCorrect ? Colors.greenAccent : Colors.redAccent,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              step.isCorrect ? 'إجابة صحيحة' : (step.selectedAnswer.isEmpty ? 'انتهى الوقت' : 'إجابة خاطئة'),
                                              style: TextStyle(
                                                color: step.isCorrect ? Colors.greenAccent : Colors.redAccent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '⏱️ ${step.timeSpent.toStringAsFixed(1)} ث',
                                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    step.questionText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'الإجابة المختارة: ${step.selectedAnswer.isEmpty ? "(لم يجب)" : step.selectedAnswer}',
                                        style: TextStyle(
                                          color: step.isCorrect ? Colors.greenAccent : Colors.redAccent,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Text(
                                        'الصحيحة: ${step.correctAnswer}',
                                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                                      ),
                                      const Spacer(),
                                      // Rollback / Undo to this step button
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (dialogCtx) => AlertDialog(
                                              backgroundColor: const Color(0xFF1E1E2E),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              title: const Text('تأكيد الرجوع لنقطة سابقة', style: TextStyle(color: Colors.white)),
                                              content: Text(
                                                'هل أنت متأكد من الرجوع إلى ما بعد الجولة رقم ${step.stepNumber}؟\nسيتم التراجع عن أي خطوات حدثت بعدها.',
                                                style: const TextStyle(color: Colors.white70),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                                                  child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
                                                  child: const Text('نعم، ارجع لهذه النقطة', style: TextStyle(color: Colors.white)),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            Navigator.of(ctx).pop();
                                            await _rollbackToStep(index);
                                          }
                                        },
                                        icon: const Icon(Icons.undo, size: 14),
                                        label: const Text('الرجوع لهذه النقطة', style: TextStyle(fontSize: 11)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber.withValues(alpha: 0.2),
                                          foregroundColor: Colors.amberAccent,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: const BorderSide(color: Colors.amberAccent, width: 0.8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تاريخ آخر حفظ تلقائي: ${gameSteps.isNotEmpty ? gameSteps.last.timestamp.toString().substring(11, 19) : "-"}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF764BA2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          ),
                          child: const Text('إغلاق'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class WinningLinePainter extends CustomPainter {
  final WinningLine winningLine;
  final double progress;
  final Player? winner;

  WinningLinePainter({
    required this.winningLine,
    required this.progress,
    this.winner,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    const double spacing = 4.0;
    final double cellWidth = (size.width - spacing * 4) / 5;
    final double cellHeight = (size.height - spacing * 4) / 5;

    double cellCenterX(int col) => col * (cellWidth + spacing) + cellWidth / 2;
    double cellCenterY(int row) =>
        row * (cellHeight + spacing) + cellHeight / 2;

    Offset p1;
    Offset p2;

    switch (winningLine.type) {
      case WinLineType.horizontal:
        final row = winningLine.index;
        p1 = Offset(cellCenterX(0), cellCenterY(row));
        p2 = Offset(cellCenterX(4), cellCenterY(row));
        break;
      case WinLineType.vertical:
        final col = winningLine.index;
        p1 = Offset(cellCenterX(col), cellCenterY(0));
        p2 = Offset(cellCenterX(col), cellCenterY(4));
        break;
      case WinLineType.mainDiagonal:
        p1 = Offset(cellCenterX(0), cellCenterY(0));
        p2 = Offset(cellCenterX(4), cellCenterY(4));
        break;
      case WinLineType.antiDiagonal:
        p1 = Offset(cellCenterX(4), cellCenterY(0));
        p2 = Offset(cellCenterX(0), cellCenterY(4));
        break;
    }

    final delta = p2 - p1;
    final distance = delta.distance;
    final direction = distance > 0 ? delta / distance : Offset.zero;
    final extension = cellWidth * 0.38;

    final startPoint = p1 - direction * extension;
    final fullEndPoint = p2 + direction * extension;
    final currentEnd =
        Offset.lerp(startPoint, fullEndPoint, progress) ?? fullEndPoint;

    // Outer glow
    final glowPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.45)
      ..strokeWidth = 18.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Main line (Championship Gold)
    final mainPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Inner highlight
    final innerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(startPoint, currentEnd, glowPaint);
    canvas.drawLine(startPoint, currentEnd, mainPaint);
    canvas.drawLine(startPoint, currentEnd, innerPaint);
  }

  @override
  bool shouldRepaint(covariant WinningLinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.winningLine != winningLine ||
        oldDelegate.winner != winner;
  }
}

class QuestionDialog extends StatefulWidget {
  final String question;
  final List<String> options;
  final String answer;
  final int questionIndex;
  final int cellIndex;
  final Player currentPlayer;
  final double questionFontSize;
  final double optionsFontSize;
  final Function(int, int, String, String, double, Player) onAnswer;

  const QuestionDialog({
    super.key,
    required this.question,
    required this.options,
    required this.answer,
    required this.questionIndex,
    required this.cellIndex,
    required this.currentPlayer,
    this.questionFontSize = 20.0,
    this.optionsFontSize = 16.0,
    required this.onAnswer,
  });

  @override
  State<QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<QuestionDialog> {
  int? selectedIndex;
  late DateTime startTime;
  Timer? _questionTimer;
  int _remainingTime = 30;

  @override
  void initState() {
    super.initState();
    startTime = DateTime.now();
    _startQuestionTimer();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    super.dispose();
  }

  void _startQuestionTimer() {
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingTime--;
        });

        if (_remainingTime <= 0) {
          timer.cancel();
          _handleTimeUp();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _handleTimeUp() {
    if (mounted) {
      Navigator.of(context).pop();
      // Call onAnswer with wrong answer and time spent
      final timeSpent =
          DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      widget.onAnswer(
        widget.questionIndex,
        widget.cellIndex,
        '', // Empty answer means time up
        widget.answer,
        timeSpent,
        widget.currentPlayer,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timer display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: _remainingTime <= 10
                    ? Colors.red.withOpacity(0.9)
                    : _remainingTime <= 20
                    ? Colors.orange.withOpacity(0.9)
                    : Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'الوقت المتبقي: $_remainingTime ثانية',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Text(
                    'دور ${widget.currentPlayer == Player.player1 ? "اللاعب الأول (X)" : "اللاعب الثاني (O)"}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.question,
                    style: TextStyle(
                      fontSize: widget.questionFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...List.generate(
              widget.options.length,
              (optionIndex) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getButtonColor(optionIndex),
                    foregroundColor: selectedIndex == optionIndex
                        ? Colors.white
                        : Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed:
                      selectedIndex != null && selectedIndex != optionIndex
                      ? null
                      : () {
                          setState(() {
                            selectedIndex = optionIndex;
                          });

                          // Calculate time spent
                          final timeSpent =
                              DateTime.now()
                                  .difference(startTime)
                                  .inMilliseconds /
                              1000.0;

                          // Wait a bit to show the result, then close dialog
                          Future.delayed(
                            const Duration(milliseconds: 1500),
                            () {
                              if (mounted) {
                                Navigator.of(context).pop();
                                widget.onAnswer(
                                  widget.questionIndex,
                                  widget.cellIndex,
                                  widget.options[optionIndex],
                                  widget.answer,
                                  timeSpent,
                                  widget.currentPlayer,
                                );
                              }
                            },
                          );
                        },
                  child: Text(
                    widget.options[optionIndex],
                    style: TextStyle(
                      fontSize: widget.optionsFontSize,
                      fontWeight: FontWeight.w500,
                      color: _getTextColor(optionIndex),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            if (selectedIndex == null)
              TextButton(
                onPressed: () {
                  _questionTimer?.cancel();
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getButtonColor(int optionIndex) {
    if (selectedIndex == optionIndex) {
      print("selected");
      return widget.options[optionIndex] == widget.answer
          ? Colors.green
          : Colors.red;
    }
    if (selectedIndex == null) {
      return Colors.white.withOpacity(0.9);
    }

    print("object");

    if (widget.options[optionIndex] == widget.answer) {
      return Colors.green.withOpacity(0.3);
    }

    return Colors.red.withOpacity(0.9);
  }

  Color _getTextColor(int optionIndex) {
    if (selectedIndex == null) {
      return Colors.black87;
    }

    if (selectedIndex == optionIndex) {
      return Colors.white;
    }

    return Colors.black87;
  }
}
