import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import 'dart:async';
import 'package:game/database/app_database.dart';
import 'package:game/services/excel_service.dart';
import 'package:game/screens/questions_page.dart';

enum GameState { waiting, playing, gameOver }

enum Player { player1, player2 }

class PlayerData {
  int score = 0;
  double totalTime = 0.0;
  List<int> occupiedCells = [];

  PlayerData();
}

enum WinLineType {
  horizontal,
  vertical,
  mainDiagonal,
  antiDiagonal,
}

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

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
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

  // Game duration
  int gameDuration = 0;

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
    _startNewGame();
  }

  Future<void> _loadQuestionsFromDb() async {
    final dbQuestions = await appDatabase.getAllQuestions();
    setState(() {
      gameQuestions = dbQuestions.map((q) => {
        'id': q.id,
        'question': q.question,
        'answer': q.answerNumber == 1
            ? q.optionA
            : q.answerNumber == 2
                ? q.optionB
                : q.answerNumber == 3
                    ? q.optionC
                    : q.optionD,
        'answerNumber': q.answerNumber,
        'isAnswer': false,
      }).toList();
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

  void _startNewGame() {
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

      // Reset questions
      for (var question in gameQuestions) {
        question["isAnswer"] = false;
      }
    });

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
        question: randomQuestion["question"],
        options: randomQuestion["options"],
        answer: randomQuestion["answer"],
        questionIndex: questionIndex,
        cellIndex: cellIndex,
        currentPlayer: currentPlayer,
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
    });
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
                          const Text(
                            "المسابقة الوطنية للمعلومات",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 14),
                          ElevatedButton.icon(
                            onPressed: _openQuestionsPage,
                            icon: const Icon(Icons.table_chart, size: 18),
                            label: Text(
                              'بنك الأسئلة (${gameQuestions.length})',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.95),
                              foregroundColor: const Color(0xFF2E7D32),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
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

                const SizedBox(height: 30),

                // Game board (5x5)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Player 1 section
                      Container(
                        width: 200,
                        child: Column(
                          children: [
                            _buildPlayerCard(
                              'اللاعب الأول',
                              player1Data.score,
                              player1Data.totalTime,
                              currentPlayer == Player.player1 &&
                                  gameState == GameState.playing,
                              Colors.blue,
                            ),
                            Image.asset('lib/s.png', width: 400, height: 400),
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
                                physics: const NeverScrollableScrollPhysics(),
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
                              if (winningLine != null && _lineAnimation != null)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: AnimatedBuilder(
                                      animation: _lineAnimation!,
                                      builder: (context, child) {
                                        return CustomPaint(
                                          painter: WinningLinePainter(
                                            winningLine: winningLine!,
                                            progress: _lineAnimation!.value,
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
                      Container(
                        width: 200,
                        child: Column(
                          children: [
                            _buildPlayerCard(
                              'اللاعب الثاني',
                              player2Data.score,
                              player2Data.totalTime,
                              currentPlayer == Player.player2 &&
                                  gameState == GameState.playing,
                              Colors.red,
                            ),
                            Image.asset('lib/m.png', width: 400, height: 400),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Game controls
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _startNewGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.9),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'لعبة جديدة',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _openQuestionsPage,
                        icon: const Icon(Icons.upload_file, size: 20),
                        label: const Text(
                          'استيراد Excel / بنك الأسئلة',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.95),
                          foregroundColor: const Color(0xFF2E7D32),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
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
                  style: const TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Text(
                  cellOwner == Player.player1 ? 'X' : 'O',
                  style: TextStyle(
                    fontSize: 35,
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
    double cellCenterY(int row) => row * (cellHeight + spacing) + cellHeight / 2;

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
  final Function(int, int, String, String, double, Player) onAnswer;

  const QuestionDialog({
    super.key,
    required this.question,
    required this.options,
    required this.answer,
    required this.questionIndex,
    required this.cellIndex,
    required this.currentPlayer,
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
        width: 350,
        padding: const EdgeInsets.all(20),
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
                    style: const TextStyle(
                      fontSize: 18,
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
                      fontSize: 16,
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
