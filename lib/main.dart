import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '2048 Dark',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0D10),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8AB4F8),
          secondary: Color(0xFF9AA4B2),
          surface: Color(0xFF111418),
        ),
      ),
      home: const Game2048Page(),
    );
  }
}

class Game2048Page extends StatefulWidget {
  const Game2048Page({super.key});

  @override
  State<Game2048Page> createState() => _Game2048PageState();
}

class _Game2048PageState extends State<Game2048Page> {
  static const int gridSize = 4;
  static const String bestScoreKey = 'best_score_2048_dark';
  static const double boardPadding = 12;
  static const double gap = 10;

  final Random _random = Random();
  final FocusNode _focusNode = FocusNode();

  late List<List<int>> _board;
  SharedPreferences? _prefs;

  int _score = 0;
  int _best = 0;
  int _animationTick = 0;

  bool _gameOver = false;
  bool _won = false;
  bool _showWinOverlay = false;

  @override
  void initState() {
    super.initState();
    _board = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    _loadPrefsAndStart();
  }

  Future<void> _loadPrefsAndStart() async {
    _prefs = await SharedPreferences.getInstance();
    _best = _prefs?.getInt(bestScoreKey) ?? 0;
    _startNewGame();
  }

  Future<void> _saveBestIfNeeded() async {
    if (_score > _best) {
      _best = _score;
      await _prefs?.setInt(bestScoreKey, _best);
    }
  }

  void _startNewGame() {
    _board = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    _score = 0;
    _gameOver = false;
    _won = false;
    _showWinOverlay = false;
    _animationTick++;
    _addRandomTile();
    _addRandomTile();
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  void _addRandomTile() {
    final emptyCells = <Point<int>>[];

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (_board[row][col] == 0) {
          emptyCells.add(Point(row, col));
        }
      }
    }

    if (emptyCells.isEmpty) return;

    final cell = emptyCells[_random.nextInt(emptyCells.length)];
    _board[cell.x][cell.y] = _random.nextDouble() < 0.9 ? 2 : 4;
  }

  void _handleSwipe(Offset velocity) {
    if (_gameOver || _showWinOverlay) return;

    final dx = velocity.dx;
    final dy = velocity.dy;

    if (dx.abs() > dy.abs()) {
      dx > 0 ? _moveRight() : _moveLeft();
    } else {
      dy > 0 ? _moveDown() : _moveUp();
    }
  }

  void _handleKey(RawKeyEvent event) {
    if (event is! RawKeyDownEvent || _gameOver || _showWinOverlay) return;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      _moveLeft();
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      _moveRight();
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyW) {
      _moveUp();
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      _moveDown();
    } else if (key == LogicalKeyboardKey.keyR) {
      _startNewGame();
    }
  }

  List<int> _compressLine(List<int> line) {
    final nonZero = line.where((value) => value != 0).toList();
    final result = <int>[];
    int index = 0;

    while (index < nonZero.length) {
      if (index < nonZero.length - 1 && nonZero[index] == nonZero[index + 1]) {
        final merged = nonZero[index] * 2;
        result.add(merged);
        _score += merged;

        if (merged == 2048 && !_won) {
          _won = true;
          _showWinOverlay = true;
        }

        index += 2;
      } else {
        result.add(nonZero[index]);
        index++;
      }
    }

    while (result.length < gridSize) {
      result.add(0);
    }

    return result;
  }

  bool _listsEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _finishTurn(bool moved) async {
    if (!moved) return;

    _animationTick++;
    HapticFeedback.lightImpact();
    _addRandomTile();
    await _saveBestIfNeeded();

    if (!_canMove()) {
      _gameOver = true;
      HapticFeedback.mediumImpact();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _moveLeft() {
    bool moved = false;

    for (int row = 0; row < gridSize; row++) {
      final original = List<int>.from(_board[row]);
      final updated = _compressLine(original);
      if (!_listsEqual(original, updated)) {
        moved = true;
        _board[row] = updated;
      }
    }

    _finishTurn(moved);
  }

  void _moveRight() {
    bool moved = false;

    for (int row = 0; row < gridSize; row++) {
      final original = List<int>.from(_board[row]);
      final reversed = List<int>.from(original.reversed);
      final updated = _compressLine(reversed).reversed.toList();
      if (!_listsEqual(original, updated)) {
        moved = true;
        _board[row] = updated;
      }
    }

    _finishTurn(moved);
  }

  void _moveUp() {
    bool moved = false;

    for (int col = 0; col < gridSize; col++) {
      final original = List<int>.generate(gridSize, (row) => _board[row][col]);
      final updated = _compressLine(original);
      if (!_listsEqual(original, updated)) {
        moved = true;
        for (int row = 0; row < gridSize; row++) {
          _board[row][col] = updated[row];
        }
      }
    }

    _finishTurn(moved);
  }

  void _moveDown() {
    bool moved = false;

    for (int col = 0; col < gridSize; col++) {
      final original = List<int>.generate(gridSize, (row) => _board[row][col]);
      final reversed = List<int>.from(original.reversed);
      final updated = _compressLine(reversed).reversed.toList();
      if (!_listsEqual(original, updated)) {
        moved = true;
        for (int row = 0; row < gridSize; row++) {
          _board[row][col] = updated[row];
        }
      }
    }

    _finishTurn(moved);
  }

  bool _canMove() {
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (_board[row][col] == 0) return true;
        if (row < gridSize - 1 && _board[row][col] == _board[row + 1][col]) {
          return true;
        }
        if (col < gridSize - 1 && _board[row][col] == _board[row][col + 1]) {
          return true;
        }
      }
    }
    return false;
  }

  Color _tileColor(int value) {
    switch (value) {
      case 0:
        return const Color(0xFF1A1E24);
      case 2:
        return const Color(0xFF20252C);
      case 4:
        return const Color(0xFF25303B);
      case 8:
        return const Color(0xFF1F3A5F);
      case 16:
        return const Color(0xFF224A7A);
      case 32:
        return const Color(0xFF2767A7);
      case 64:
        return const Color(0xFF2E81D1);
      case 128:
        return const Color(0xFF5E8DFF);
      case 256:
        return const Color(0xFF7A7CFF);
      case 512:
        return const Color(0xFF8E63FF);
      case 1024:
        return const Color(0xFF9A4DFF);
      case 2048:
        return const Color(0xFFB43DFF);
      default:
        return const Color(0xFFDCE7FF);
    }
  }

  Color _textColor(int value) {
    return value <= 4 ? const Color(0xFFE5EDF8) : Colors.white;
  }

  double _fontSize(int value) {
    if (value < 100) return 30;
    if (value < 1000) return 26;
    return 20;
  }

  Widget _buildStatCard(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF12161D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1D232C)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8E98A6),
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: Text(
              '$value',
              key: ValueKey('${label}_$value'),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(int value, double size) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('tile_$value$_animationTick'),
      tween: Tween(begin: 0.88, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _tileColor(value),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(value >= 8 ? 0.08 : 0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: _tileColor(value).withOpacity(0.24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Text(
            '$value',
            key: ValueKey('value_$value$_animationTick'),
            style: TextStyle(
              color: _textColor(value),
              fontWeight: FontWeight.w900,
              fontSize: _fontSize(value),
              letterSpacing: -0.8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, 430.0);
        final tileSize =
            (size - (boardPadding * 2) - (gap * (gridSize - 1))) / gridSize;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1318),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF1D232C)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 28,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(boardPadding),
                child: Column(
                  children: List.generate(gridSize, (row) {
                    return Expanded(
                      child: Row(
                        children: List.generate(gridSize, (col) {
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                right: col < gridSize - 1 ? gap : 0,
                                bottom: row < gridSize - 1 ? gap : 0,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF171C22),
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(boardPadding),
                child: Stack(
                  children: [
                    for (int row = 0; row < gridSize; row++)
                      for (int col = 0; col < gridSize; col++)
                        if (_board[row][col] != 0)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 120),
                            curve: Curves.easeOut,
                            left: col * (tileSize + gap),
                            top: row * (tileSize + gap),
                            width: tileSize,
                            height: tileSize,
                            child: _buildTile(_board[row][col], tileSize),
                          ),
                  ],
                ),
              ),
              if (_gameOver || _showWinOverlay)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF090B0E).withOpacity(0.74),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        width: min(size - 48, 280),
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: const Color(0xFF11161D),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFF212833)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _gameOver ? 'Fim de jogo' : '2048 alcançado',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _gameOver
                                  ? 'Não há mais movimentos disponíveis.'
                                  : 'Você pode continuar jogando ou começar outra partida.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: Color(0xFF9CA7B6),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_showWinOverlay)
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () {
                                    setState(() {
                                      _showWinOverlay = false;
                                    });
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF5E8DFF),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text('Continuar'),
                                ),
                              ),
                            if (_showWinOverlay) const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _startNewGame,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: Color(0xFF2A3441),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text('Nova partida'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '2048',
                style: TextStyle(
                  fontSize: 52,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1.5,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Deslize para unir blocos iguais e alcançar 2048.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Color(0xFF98A3B3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            _buildStatCard('SCORE', _score),
            const SizedBox(height: 10),
            _buildStatCard('BEST', _best),
          ],
        ),
      ],
    );
  }

  Widget _buildTopActions() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF11161D),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF1D232C)),
            ),
            child: const Text(
              'Controles: swipe, setas/WASD e R para reiniciar.',
              style: TextStyle(
                color: Color(0xFF99A5B4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: _startNewGame,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF5E8DFF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('Reiniciar'),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF11161D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1D232C)),
      ),
      child: const Text(
        'Dica: tente manter os valores altos em um dos cantos e organize os movimentos para não quebrar a sequência.',
        style: TextStyle(color: Color(0xFF97A2B0), height: 1.5),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RawKeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKey: _handleKey,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanEnd: (details) =>
                _handleSwipe(details.velocity.pixelsPerSecond),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 18),
                      _buildTopActions(),
                      const SizedBox(height: 18),
                      _buildBoard(),
                      const SizedBox(height: 18),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
