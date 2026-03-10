import 'dart:async';
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

enum MoveDirection { left, right, up, down }

class TileModel {
  TileModel({
    required this.id,
    required this.value,
    required this.row,
    required this.col,
    this.scale = 1,
    this.opacity = 1,
    this.zIndex = 1,
    this.isPulsing = false,
  });

  final int id;
  int value;
  int row;
  int col;
  double scale;
  double opacity;
  int zIndex;
  bool isPulsing;
}

class CellCoord {
  const CellCoord(this.row, this.col);

  final int row;
  final int col;
}

class MovePlan {
  MovePlan({
    required this.targets,
    required this.mergeInto,
    required this.mergedValues,
    required this.finalGrid,
    required this.gainedScore,
    required this.reached2048,
    required this.moved,
  });

  final Map<int, CellCoord> targets;
  final Map<int, int> mergeInto;
  final Map<int, int> mergedValues;
  final List<List<int?>> finalGrid;
  final int gainedScore;
  final bool reached2048;
  final bool moved;
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

  static const Duration moveDuration = Duration(milliseconds: 145);
  static const Duration mergePeakDuration = Duration(milliseconds: 120);
  static const Duration mergeSettleDuration = Duration(milliseconds: 110);

  final Random _random = Random();
  final FocusNode _focusNode = FocusNode();

  SharedPreferences? _prefs;

  final Map<int, TileModel> _tiles = <int, TileModel>{};
  late List<List<int?>> _grid;

  int _score = 0;
  int _best = 0;
  int _nextTileId = 0;
  int _boardEpoch = 0;

  bool _gameOver = false;
  bool _won = false;
  bool _showWinOverlay = false;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _grid = List.generate(gridSize, (_) => List<int?>.filled(gridSize, null));
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
    _boardEpoch++;
    _tiles.clear();
    _grid = List.generate(gridSize, (_) => List<int?>.filled(gridSize, null));
    _score = 0;
    _gameOver = false;
    _won = false;
    _showWinOverlay = false;
    _isAnimating = false;

    _spawnRandomTile(animate: false);
    _spawnRandomTile(animate: false);

    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  TileModel _createTile({
    required int value,
    required int row,
    required int col,
    double scale = 1,
  }) {
    final tile = TileModel(
      id: _nextTileId++,
      value: value,
      row: row,
      col: col,
      scale: scale,
      zIndex: 5,
    );
    _tiles[tile.id] = tile;
    _grid[row][col] = tile.id;
    return tile;
  }

  void _spawnRandomTile({bool animate = true}) {
    final emptyCells = <CellCoord>[];

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (_grid[row][col] == null) {
          emptyCells.add(CellCoord(row, col));
        }
      }
    }

    if (emptyCells.isEmpty) return;

    final chosen = emptyCells[_random.nextInt(emptyCells.length)];
    final value = _random.nextDouble() < 0.9 ? 2 : 4;
    final tile = _createTile(
      value: value,
      row: chosen.row,
      col: chosen.col,
      scale: animate ? 0.0 : 1.0,
    );

    if (!animate || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tiles.containsKey(tile.id)) return;
      setState(() {
        tile.scale = 1.0;
        tile.zIndex = 1;
      });
    });
  }

  void _handleSwipe(Offset velocity) {
    if (_gameOver || _showWinOverlay || _isAnimating) return;

    final dx = velocity.dx;
    final dy = velocity.dy;

    if (dx.abs() < 150 && dy.abs() < 150) return;

    if (dx.abs() > dy.abs()) {
      dx > 0
          ? _performMove(MoveDirection.right)
          : _performMove(MoveDirection.left);
    } else {
      dy > 0
          ? _performMove(MoveDirection.down)
          : _performMove(MoveDirection.up);
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        _gameOver ||
        _showWinOverlay ||
        _isAnimating) {
      return;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      _performMove(MoveDirection.left);
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      _performMove(MoveDirection.right);
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyW) {
      _performMove(MoveDirection.up);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      _performMove(MoveDirection.down);
    } else if (key == LogicalKeyboardKey.keyR) {
      _startNewGame();
    }
  }

  MovePlan _buildMovePlan(MoveDirection direction) {
    final targets = <int, CellCoord>{};
    final mergeInto = <int, int>{};
    final mergedValues = <int, int>{};
    final finalGrid = List.generate(
      gridSize,
      (_) => List<int?>.filled(gridSize, null),
    );

    int gainedScore = 0;
    bool reached2048 = false;

    for (int fixed = 0; fixed < gridSize; fixed++) {
      final idsInLine = <int>[];
      for (int lineIndex = 0; lineIndex < gridSize; lineIndex++) {
        final coord = _coordFromLine(direction, fixed, lineIndex);
        final tileId = _grid[coord.row][coord.col];
        if (tileId != null) {
          idsInLine.add(tileId);
        }
      }

      int targetIndex = 0;
      int cursor = 0;

      while (cursor < idsInLine.length) {
        final firstId = idsInLine[cursor];
        final firstValue = _tiles[firstId]!.value;

        if (cursor + 1 < idsInLine.length) {
          final secondId = idsInLine[cursor + 1];
          final secondValue = _tiles[secondId]!.value;

          if (firstValue == secondValue) {
            final target = _coordFromLine(direction, fixed, targetIndex);
            final mergedValue = firstValue * 2;

            targets[firstId] = target;
            targets[secondId] = target;
            mergeInto[secondId] = firstId;
            mergedValues[firstId] = mergedValue;
            finalGrid[target.row][target.col] = firstId;

            gainedScore += mergedValue;
            if (mergedValue == 2048) {
              reached2048 = true;
            }

            targetIndex++;
            cursor += 2;
            continue;
          }
        }

        final target = _coordFromLine(direction, fixed, targetIndex);
        targets[firstId] = target;
        finalGrid[target.row][target.col] = firstId;
        targetIndex++;
        cursor++;
      }
    }

    bool moved = mergeInto.isNotEmpty;
    if (!moved) {
      for (final entry in targets.entries) {
        final tile = _tiles[entry.key]!;
        if (tile.row != entry.value.row || tile.col != entry.value.col) {
          moved = true;
          break;
        }
      }
    }

    return MovePlan(
      targets: targets,
      mergeInto: mergeInto,
      mergedValues: mergedValues,
      finalGrid: finalGrid,
      gainedScore: gainedScore,
      reached2048: reached2048,
      moved: moved,
    );
  }

  CellCoord _coordFromLine(MoveDirection direction, int fixed, int index) {
    switch (direction) {
      case MoveDirection.left:
        return CellCoord(fixed, index);
      case MoveDirection.right:
        return CellCoord(fixed, gridSize - 1 - index);
      case MoveDirection.up:
        return CellCoord(index, fixed);
      case MoveDirection.down:
        return CellCoord(gridSize - 1 - index, fixed);
    }
  }

  Future<void> _performMove(MoveDirection direction) async {
    if (_isAnimating || _gameOver || _showWinOverlay) return;

    final plan = _buildMovePlan(direction);
    if (!plan.moved) return;

    final epoch = _boardEpoch;
    _isAnimating = true;
    HapticFeedback.lightImpact();

    for (final tile in _tiles.values) {
      tile.zIndex = 1;
      tile.isPulsing = false;
      tile.scale = 1.0;
    }

    for (final entry in plan.targets.entries) {
      final tile = _tiles[entry.key]!;
      tile.row = entry.value.row;
      tile.col = entry.value.col;
      if (plan.mergeInto.containsKey(entry.key)) {
        tile.zIndex = 4;
      } else if (plan.mergedValues.containsKey(entry.key)) {
        tile.zIndex = 3;
      }
    }

    if (mounted) {
      setState(() {});
    }

    await Future.delayed(moveDuration);
    if (!mounted || epoch != _boardEpoch) return;

    for (final consumedId in plan.mergeInto.keys) {
      _tiles.remove(consumedId);
    }

    _grid = plan.finalGrid;
    _score += plan.gainedScore;
    _won = _won || plan.reached2048;
    if (plan.reached2048) {
      _showWinOverlay = true;
      HapticFeedback.mediumImpact();
    }

    await _saveBestIfNeeded();

    for (final entry in plan.mergedValues.entries) {
      final tile = _tiles[entry.key];
      if (tile != null) {
        tile.value = entry.value;
        tile.scale = 1.18;
        tile.isPulsing = true;
        tile.zIndex = 6;
      }
    }

    if (mounted) {
      setState(() {});
    }

    if (plan.mergedValues.isNotEmpty) {
      await Future.delayed(mergePeakDuration);
      if (!mounted || epoch != _boardEpoch) return;

      for (final tileId in plan.mergedValues.keys) {
        final tile = _tiles[tileId];
        if (tile != null) {
          tile.scale = 1.0;
        }
      }

      if (mounted) {
        setState(() {});
      }

      await Future.delayed(mergeSettleDuration);
      if (!mounted || epoch != _boardEpoch) return;

      for (final tileId in plan.mergedValues.keys) {
        final tile = _tiles[tileId];
        if (tile != null) {
          tile.isPulsing = false;
          tile.zIndex = 1;
        }
      }
    }

    if (!mounted || epoch != _boardEpoch) return;

    _spawnRandomTile();

    if (!_canMove()) {
      _gameOver = true;
      HapticFeedback.mediumImpact();
    }

    _isAnimating = false;
    if (mounted) {
      setState(() {});
    }
  }

  bool _canMove() {
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final tileId = _grid[row][col];
        if (tileId == null) {
          return true;
        }

        if (row < gridSize - 1) {
          final bottomId = _grid[row + 1][col];
          if (bottomId != null &&
              _tiles[bottomId]!.value == _tiles[tileId]!.value) {
            return true;
          }
        }

        if (col < gridSize - 1) {
          final rightId = _grid[row][col + 1];
          if (rightId != null &&
              _tiles[rightId]!.value == _tiles[tileId]!.value) {
            return true;
          }
        }
      }
    }

    return false;
  }

  Color _tileColor(int value) {
    switch (value) {
      case 2:
        return const Color(0xFF20252C);
      case 4:
        return const Color(0xFF27303A);
      case 8:
        return const Color(0xFF1F3C62);
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
    return value <= 4 ? const Color(0xFFE8EEF9) : Colors.white;
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

  Widget _buildTile(TileModel tile, double size) {
    final baseColor = _tileColor(tile.value);

    return AnimatedPositioned(
      key: ValueKey(tile.id),
      duration: moveDuration,
      curve: Curves.easeOutCubic,
      left: tile.col * (size + gap),
      top: tile.row * (size + gap),
      width: size,
      height: size,
      child: IgnorePointer(
        child: AnimatedScale(
          scale: tile.scale,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: tile.opacity,
            duration: const Duration(milliseconds: 120),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [baseColor.withOpacity(0.96), baseColor],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(tile.isPulsing ? 0.16 : 0.07),
                ),
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withOpacity(tile.isPulsing ? 0.42 : 0.22),
                    blurRadius: tile.isPulsing ? 26 : 16,
                    spreadRadius: tile.isPulsing ? 1.5 : 0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: size * 0.34,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(
                              tile.isPulsing ? 0.14 : 0.09,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 120),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: Text(
                        '${tile.value}',
                        key: ValueKey('value_${tile.id}_${tile.value}'),
                        style: TextStyle(
                          color: _textColor(tile.value),
                          fontWeight: FontWeight.w900,
                          fontSize: _fontSize(tile.value),
                          letterSpacing: -0.9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
        final sortedTiles = _tiles.values.toList()
          ..sort((a, b) {
            final z = a.zIndex.compareTo(b.zIndex);
            if (z != 0) return z;
            return a.id.compareTo(b.id);
          });

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
                    for (final tile in sortedTiles) _buildTile(tile, tileSize),
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
                                    _focusNode.requestFocus();
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
            child: Text(
              _isAnimating ? 'Animando movimento...' : 'Controles: swipe.',
              style: const TextStyle(
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
        'Dica: mantenha os maiores valores em um canto e use as outras linhas para preparar merges em sequência.',
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
        child: KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKey,
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
