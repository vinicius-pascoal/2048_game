import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '2048 Flutter',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8F7A66)),
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
  static const double boardPadding = 12;
  static const double gap = 10;

  final Random _random = Random();
  late List<List<int>> _board;
  int _score = 0;
  int _best = 0;
  bool _gameOver = false;
  bool _won = false;
  bool _movedInLastTurn = false;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    _board = List.generate(gridSize, (_) => List.generate(gridSize, (_) => 0));
    _score = 0;
    _gameOver = false;
    _won = false;
    _addRandomTile();
    _addRandomTile();
    setState(() {});
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

    final chosen = emptyCells[_random.nextInt(emptyCells.length)];
    _board[chosen.x][chosen.y] = _random.nextDouble() < 0.9 ? 2 : 4;
  }

  void _handleSwipe(Offset velocity) {
    if (_gameOver) return;

    final dx = velocity.dx;
    final dy = velocity.dy;

    if (dx.abs() > dy.abs()) {
      if (dx > 0) {
        _moveRight();
      } else {
        _moveLeft();
      }
    } else {
      if (dy > 0) {
        _moveDown();
      } else {
        _moveUp();
      }
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
        if (merged == 2048) {
          _won = true;
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

  void _finishTurn(bool moved) {
    _movedInLastTurn = moved;
    if (!moved) return;

    _addRandomTile();
    if (_score > _best) {
      _best = _score;
    }

    if (!_canMove()) {
      _gameOver = true;
    }

    setState(() {});
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
        return const Color(0xFFCDC1B4);
      case 2:
        return const Color(0xFFEEE4DA);
      case 4:
        return const Color(0xFFEDE0C8);
      case 8:
        return const Color(0xFFF2B179);
      case 16:
        return const Color(0xFFF59563);
      case 32:
        return const Color(0xFFF67C5F);
      case 64:
        return const Color(0xFFF65E3B);
      case 128:
        return const Color(0xFFEDCF72);
      case 256:
        return const Color(0xFFEDCC61);
      case 512:
        return const Color(0xFFEDC850);
      case 1024:
        return const Color(0xFFEDC53F);
      case 2048:
        return const Color(0xFFEDC22E);
      default:
        return const Color(0xFF3C3A32);
    }
  }

  Color _textColor(int value) {
    return value <= 4 ? const Color(0xFF776E65) : Colors.white;
  }

  double _fontSize(int value) {
    if (value < 100) return 32;
    if (value < 1000) return 28;
    return 22;
  }

  Widget _buildScoreBox(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFBBADA0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFEEE4DA),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, 420.0);
        final tileSize =
            (size - (boardPadding * 2) - (gap * (gridSize - 1))) / gridSize;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFBBADA0),
                  borderRadius: BorderRadius.circular(18),
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
                                color: const Color(0xFFCDC1B4),
                                borderRadius: BorderRadius.circular(12),
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
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              decoration: BoxDecoration(
                                color: _tileColor(_board[row][col]),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Text(
                                    '${_board[row][col]}',
                                    style: TextStyle(
                                      color: _textColor(_board[row][col]),
                                      fontSize: _fontSize(_board[row][col]),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
              if (_gameOver || _won)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _gameOver ? 'Game Over' : 'Você chegou em 2048!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF776E65),
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _startNewGame,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF8F7A66),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Jogar novamente'),
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8EF),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanEnd: (details) => _handleSwipe(details.velocity.pixelsPerSecond),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '2048',
                                style: TextStyle(
                                  fontSize: 54,
                                  height: 1,
                                  color: Color(0xFF776E65),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Deslize para mover os blocos e combine números iguais.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF776E65),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            _buildScoreBox('SCORE', _score),
                            const SizedBox(height: 10),
                            _buildScoreBox('BEST', _best),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE0C8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Objetivo: alcançar o bloco 2048.',
                              style: TextStyle(
                                color: Color(0xFF776E65),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _startNewGame,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF8F7A66),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Reiniciar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _buildBoard(),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1E7D8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Como jogar: deslize para cima, baixo, esquerda ou direita. Quando dois blocos iguais se encostam, eles se unem em um só.',
                        style: TextStyle(
                          color: Color(0xFF776E65),
                          height: 1.45,
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
    );
  }
}
